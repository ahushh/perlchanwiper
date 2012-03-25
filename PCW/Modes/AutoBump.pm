package PCW::Modes::AutoBump;

use strict;
use autodie;
use Carp;
use feature qw(switch say);

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
#-- Время запуска следующего бампа
my $run_at = 0;

my $bump_queue   = Coro::Channel->new();
my $delete_queue = Coro::Channel->new();
my %stats        = (error => 0, bumped  => 0, total => 0, wait           => 0);
my %del_stats    = (error => 0, deleted => 0, total => 0, wrong_password => 0);

sub show_stats
{
    say "\nBump stats:";
    say "Bumped: $stats{bumped}";
    say "Wait: $stats{wait}";
    say "Error: $stats{error}";
    say "Total: $stats{total}";
    say "Delete stats:";
    say "Successfully deleted: $del_stats{deleted}";
    say "Wrong password: $del_stats{wrong_password}";
    say "Error: $del_stats{error}";
    say "Total: $del_stats{total}";
};

#------------------------------------------------------------------------------------------------
#--------------------------------------  BUMP THREAD  -------------------------------------------
#------------------------------------------------------------------------------------------------
#-- Coro callback
my $cb_bump_thread = unblock_sub
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
        echo_proxy(1, "green", $task->{proxy}, "No. ". $task->{thread}, "sleep $cnf->{interval} seconds...");

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
        echo_proxy(1, "green", $task->{proxy}, "No. ". $task->{thread}, "sleep $cnf->{interval} seconds...");
    }
    else #-- Меняем прокси на следующую
    {
        # my $proxy = shift @proxies;
        # echo_msg($LOGLEVEL >= 3, "Something wrong with $proxy proxy. Switching to $proxy.");
        # $task->{proxy} = $proxy;
        # push @proxies, $proxy;
    }
    $bump_queue->put($task);
};

sub is_need_to_bump($$$)
{
    my ($engine, $task, $cnf) = @_;
    my $thread = $cnf->{post_cnf}{thread};
    my %check_cnf = ( proxy => $task->{proxy}, board => $cnf->{post_cnf}{board}, thread => $cnf->{post_cnf}{thread} );
    if ($cnf->{bump_if}{on_pages})
    {
        echo_proxy(1, "green", $task->{proxy}, "No. ". $task->{thread}, "Checking whether thread needs to bump...");
        my @pages = @{ $cnf->{bump_if}{on_pages} };
        for my $page (@pages)
        {
            $check_cnf{page} = $page;
            my $is_it = $engine->is_thread_on_page(%check_cnf);
            if ($is_it)
            {
                echo_proxy(1, "green", $task->{proxy}, "No. ". $task->{thread}, "Thread needs to be bumped!");
                return 1;
            }
        }
        echo_proxy(1, "green", $task->{proxy}, "No. ". $task->{thread}, "Thread doesn't need to bump");
        return undef;
    }
    elsif ($cnf->{bump_if}{not_on_pages})
    {
        echo_proxy(1, "green", $task->{proxy}, "No. ". $task->{thread}, "Checking whether thread needs to bump...");
        my @pages = @{ $cnf->{bump_if}{not_on_pages} };
        for my $page (@pages)
        {
            $check_cnf{page} = $page;
            my $is_it = $engine->is_thread_on_page(%check_cnf);
            if ($is_it)
            {
                echo_proxy(1, "green", $task->{proxy}, "No. ". $task->{thread}, "Thread doesn't need to bump");
                return undef;
            }
        }
        echo_proxy(1, "green", $task->{proxy}, "No. ". $task->{thread}, "Thread needs to be bumped!");
        return 1;
    }
}

sub bump_thread($$$)
{
    my ($engine, $task, $cnf) = @_;
    async {
        my $coro = $Coro::current;
        $coro->desc('bump');
        $coro->{task} = $task;
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
my $cb_delete_post = unblock_sub
{
    my ($msg, $task, $cnf) = @_;
    $del_stats{total}++;
    given ($msg)
    {
        when ('success')
        {
            $del_stats{deleted}++;
        }
        when ('wrong_password')
        {
            $del_stats{wrong_password}++;
        }
        default
        {
            $del_stats{error}++;
        }
    }
};

sub delete_post($$$)
{
    my ($engine, $task, $cnf) = @_;
    async {
        my $coro = $Coro::current;
        $coro->desc('delete');
        $coro->{task} = $task;
        $coro->on_destroy($cb_delete_post);
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
    echo_proxy(1, "green", $task->{proxy}, $task->{thread}, "Start deleting posts...");
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
    my $proxy = shift @{ $cnf{proxies} };
    $bump_queue->put({ proxy => $proxy, thread => $cnf{post_cnf}{thread} });

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
                    echo_proxy(1, 'red', $coro->{task}{proxy}, uc($coro->{desc}), '[TIMEOUT]');
                    $coro->cancel('timeout', $coro->{task}, \%cnf);
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

            #-- Ждем, если уже запущен бамп или удаление
            return if (scalar @bump_coro or scalar @delete_coro);
            my $now = Time::HiRes::time;
            #-- Или если время еще не пришло
            return if ($now < $run_at);

            my $task = $bump_queue->get;
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
