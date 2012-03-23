package PCW::Modes::AutoBump;

use strict;
use autodie;
use Carp;

#------------------------------------------------------------------------------------------------
# Package Variables
#------------------------------------------------------------------------------------------------
our $LOGLEVEL = 0;
our $VERBOSE  = 0;
 
#------------------------------------------------------------------------------------------------
# Importing Coro packages
#------------------------------------------------------------------------------------------------
use AnyEvent;
use Coro::State;
use Coro::LWP;
use Coro::Timer;
use Coro;
use EV;
use Time::HiRes;
 
#------------------------------------------------------------------------------------------------
# Importing utility packages
#------------------------------------------------------------------------------------------------
use File::Basename;
use File::Copy qw(move);
 
#------------------------------------------------------------------------------------------------
# Importing internal PCW packages
#------------------------------------------------------------------------------------------------
use PCW::Core::Log     qw(echo_msg echo_proxy);
use PCW::Core::Utils   qw(with_coro_timeout);
use PCW::Core::Captcha qw(captcha_report_bad);
use PCW::Modes::Common qw(get_posts_by_regexp);
 
#------------------------------------------------------------------------------------------------
# Local package variables and procedures
#------------------------------------------------------------------------------------------------
my $bump_queue   = Coro::Channel->new();
my $delete_queue = Coro::Channel->new();
my %stats = (error => 0, bumped => 0, total => 0, deleted => 0, wait => 0);

my $run_at = 0;
my @proxies;

sub show_stats
{
    print "\nBumped: $stats{bumped}\n";
    print "Deleted: $stats{deleted}\n";
    print "Wait: $stats{wait}\n";
    print "Error: $stats{error}\n";
    print "Total: $stats{total}\n";
};

#------------------------------------------------------------------------------------------------
#--------------------------------------  BUMP THREAD  -------------------------------------------
#------------------------------------------------------------------------------------------------
#-- Coro callback
my $cb_bump_thread = sub
{
    my ($msg, $engine, $task, $cnf) = @_;
    echo_msg($LOGLEVEL >= 4, "cb_bump_thread(): message: $msg");
    #-- Delete temporary files
    unlink($task->{path_to_captcha})
        if !$cnf->{save_captcha} && $task->{path_to_captcha} && -e $task->{path_to_captcha};
    unlink($task->{file_path})
        if $cnf->{img_data}{altering} && $task->{file_path} && -e $task->{file_path};

    $stats{total}++;
    if ($msg eq 'success')
    {
        $stats{bumped}++;

        my $now = Time::HiRes::time;
        $run_at = $now + $cnf->{interval};
        echo_msg(1, "sleep ". $cnf->{interval} ." seconds...");

        echo_msg($LOGLEVEL >= 4, "run_cleanup(): try to start");
        run_cleanup($engine, $task, $cnf->{silent}) if ($cnf->{silent});
    }
    elsif ($msg eq 'wrong_captcha')
    {
        $stats{error}++;
    }
    elsif ($msg eq 'wait')
    {
        $stats{wait}++;
        my $now = Time::HiRes::time;
        $run_at = $now + $cnf->{interval};
        echo_msg(1, "sleep ". $cnf->{interval} ." seconds...");
    }
    else #-- Меняем прокси на следующую
    {
        #my $proxy = shift @proxies;
        #unless ($proxy)
        #{
            #echo_msg(1, "All proxies are dead");
            #EV::break;
            #show_stats();
            #exit;
        #}
        #$task->{proxy} = $proxy;
    }
    $bump_queue->put($task);
};

sub is_need_to_bump($$$)
{
    my ($engine, $task, $cnf) = @_;
    my %check_cnf = ( proxy => $task->{proxy}, board => $cnf->{post_cnf}{board}, thread => $cnf->{post_cnf}{thread} );
    if ($cnf->{bump_if} && $cnf->{bump_if}{not_on_page} >= 1)
    {
        echo_msg(1, "Checking whether thread needs to bump..");
        $check_cnf{page} = $cnf->{bump_if}{not_on_page} - 1;
        my $is_it = $engine->is_thread_on_page(%check_cnf);
        if ($is_it)
        {
            echo_msg(1, "Thread doesn't need to bump");
            return undef;
        }
    }
    elsif ($cnf->{bump_if} && $cnf->{bump_if}{on_page} >= 1)
    {
        echo_msg(1, "Checking whether thread needs to bump..");
        $check_cnf{page} = $cnf->{bump_if}{on_page} - 1;
        my $is_it = $engine->is_thread_on_page(%check_cnf);
        unless ($is_it)
        {
            echo_msg(1, "Thread doesn't need to bump");
            return undef;
        }
    }
    return 1;
}

sub bump_thread($$$)
{
    my ($engine, $task, $cnf) = @_;
    async {
        my $coro = $Coro::current;
        $coro->desc('bump');
        $coro->{proxy} = $task->{proxy}; #-- Для вывода timeout
        $coro->on_destroy($cb_bump_thread);
        $coro->cancel('wait', $engine, $task, $cnf)
            unless is_need_to_bump($engine, $task, $cnf);
        my $status = 
        with_coro_timeout {
            my $status = $engine->get($task, $cnf);
            $coro->cancel($status, $task, $cnf) if ($status ne 'success');

            $status = $engine->prepare($task, $cnf);
            $coro->cancel($status, $task, $cnf) if ($status ne 'success');

            $status = $engine->post($task, $cnf);

        } $coro, $cnf->{timeout};
        $coro->cancel($status, $engine, $task, $cnf);
    };
    cede;
}

#------------------------------------------------------------------------------------------------
#--------------------------------------  DELETE BUMP  -------------------------------------------
#------------------------------------------------------------------------------------------------
#-- Coro callback
sub delete_post($$$)
{
    my ($engine, $task, $cnf) = @_;
    async {
        my $coro = $Coro::current;
        $coro->desc('delete');
        $coro->{proxy} = $task->{proxy}; #-- Для вывода timeout
        #$coro->on_destroy($cb_delete_post);
        my $status =
        with_coro_timeout {
            $engine->delete($task, $cnf);
        } $coro, $cnf->{delete_timeout};
        $coro->cancel($status, $task, $cnf);
    };
    cede;
}

sub run_cleanup($$$)
{
    my ($engine, $task, $cnf) = @_;
    echo_msg(1, "Start deleting posts...");
    my @deletion_posts = get_posts_by_regexp($task->{proxy}, $engine, $cnf->{find});

    echo_msg($LOGLEVEL >= 4, "run_cleanup(): \@deletion_posts: @deletion_posts");

    for my $postid (@deletion_posts)
    {
        my $task = {
            proxy    => $task->{proxy},
            board    => $cnf->{board},
            password => $cnf->{password},
            delete   => $postid,
        };
        $delete_queue->put($task);
    }
}

#------------------------------------------------------------------------------------------------
#---------------------------------------  BUMP MAIN  --------------------------------------------
#------------------------------------------------------------------------------------------------
sub bump($$%)
{
    my ($self, $engine, %cnf) =  @_;

    #-- Initialization
    $PCW::Modes::Common::VERBOSE = $VERBOSE;
    $PCW::Modes::Common::LOGLEVEL = $LOGLEVEL;

    @proxies = @{ $cnf{proxies} };
    my $proxy = shift @proxies;
    $bump_queue->put({ proxy => $proxy });

    #-- Timeout watcher
    my $tw = AnyEvent->timer(after => 0.5, interval => 1, cb =>
        sub
        {
            my @bump_coro   = grep { $_->desc ? ($_->desc eq 'bump')   : 0 } Coro::State::list;
            my @delete_coro = grep { $_->desc ? ($_->desc eq 'delete') : 0 } Coro::State::list;

            echo_msg($LOGLEVEL >= 3, sprintf "run: %d bump, %d delete.",
                scalar @bump_coro, scalar @delete_coro);
            echo_msg($LOGLEVEL >= 3, sprintf "queue: %d bump, %d delete.",
                $bump_queue->size, $delete_queue->size);

            for my $coro (@bump_coro, @delete_coro)
            {
                my $now = Time::HiRes::time;
                if ($coro->{timeout_at} && $now > $coro->{timeout_at})
                {
                    echo_msg($LOGLEVEL >= 4, "time left before timeout: ". int($coro->{timeout_at} - $now));
                    echo_proxy(1, 'red', $coro->{proxy}, uc($coro->{desc}), '[TIMEOUT]');
                    $coro->cancel('timeout');
                }
            }
        }
    );

    #-- Bump watcher
    my $bw = AnyEvent->timer(after => 0.5, interval => 1, cb =>
    # my $bw = AnyEvent->timer(after => 0.5, interval => $cnf{interval}, cb =>
        sub
        {
            my @bump_coro   = grep { $_->desc ? ($_->desc eq 'bump')   : 0 } Coro::State::list;
            my @delete_coro = grep { $_->desc ? ($_->desc eq 'delete') : 0 } Coro::State::list;

            my $now = Time::HiRes::time;
            echo_msg($LOGLEVEL >= 4, "time left before run a new bumping: ". int($run_at - $now));

            return if (scalar @bump_coro or scalar @delete_coro);

            return if ($now < $run_at);

            my $task = $bump_queue->get;
            echo_msg($LOGLEVEL >= 4, "bump_thread();");
            bump_thread($engine, $task, \%cnf);
        }
    );

	#-- Delete watcher
    my $dw = AnyEvent->timer(after => 1, interval => 2, cb =>
        sub
        {
            my @delete_coro = grep { $_->desc ? ($_->desc eq 'delete') : 0 } Coro::State::list;

            my $thrs_available = -1;
            #-- Max delete threads limit
            if ($cnf{silent}->{max_del_thrs})
            {
                my $n = $cnf{silent}->{max_del_thrs} - scalar @delete_coro;
                $thrs_available = $n > 0 ? $n : 0;
            }

            delete_post($engine, $delete_queue->get, $cnf{silent})
                while $delete_queue->size && $thrs_available--;
        }
    ) if $cnf{silent};

    #-- Signal watcher
    my $sw = AnyEvent->signal(signal => 'INT', cb =>
        sub
        {
            EV::break;
            show_stats();
            exit;
        }
    );

    EV::run;
}

1;
