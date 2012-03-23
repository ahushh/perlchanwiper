package PCW::Modes::Delete;

use strict;
use autodie;
use Carp;
use feature 'switch';

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
# Importing internal PCW packages
#------------------------------------------------------------------------------------------------
use PCW::Core::Log   qw(echo_msg echo_proxy);
use PCW::Core::Net   qw(http_get);
use PCW::Core::Utils qw(with_coro_timeout);

use PCW::Modes::Common qw(get_posts_by_regexp);

#------------------------------------------------------------------------------------------------
# Local package variables and procedures
#------------------------------------------------------------------------------------------------
my $delete_queue = Coro::Channel->new();
my %stats  = (error => 0, deleted => 0, total => 0);

sub show_stats()
{
    print "\nSuccessfully deleted: $stats{deleted}\n";
    print "Error: $stats{error}\n";
    print "Total: $stats{total}\n";
};

#------------------------------------------------------------------------------------------------
#----------------------------------  DELETE POST  -----------------------------------------------
#------------------------------------------------------------------------------------------------
#-- Coro callback
my $cb_delete_post = sub
{
    my ($msg, $task, $cnf) = @_;
    $stats{total}++;
    given ($msg)
    {
        when ('success')
        {
            $stats{deleted}++;
        }
        default
        {
            $stats{error}++;
        }
    }
};

sub delete_post($$$)
{
    my ($engine, $task, $cnf) = @_;
    async {
        my $coro = $Coro::current;
        $coro->desc('delete');
        $coro->{proxy} = $task->{proxy}; #-- Для вывода timeout
        $coro->on_destroy($cb_delete_post);
        my $status =
        with_coro_timeout {
            $engine->delete($task, $cnf);
        } $coro, $cnf->{delete_timeout};
        $coro->cancel($status, $task, $cnf);
    };
    cede;
}

#------------------------------------------------------------------------------------------------
#------------------------------------  MAIN DELETE  ---------------------------------------------
#------------------------------------------------------------------------------------------------
sub delete($$$%)
{
    my ($self, $engine, %cnf) =  @_;

    my $proxy = shift @{ $cnf{proxies} };
    echo_msg($LOGLEVEL >= 2, "Used proxy: $proxy");
    #-------------------------------------------------------------------
    #-- Initialization
    #-------------------------------------------------------------------
    $PCW::Modes::Common::VERBOSE  = $VERBOSE;
    $PCW::Modes::Common::LOGLEVEL = $LOGLEVEL;

    my @deletion_posts;
    if ($cnf{find}{by_id})
    {
        @deletion_posts = @{ $cnf{find}{by_id} };
    }
    elsif ($cnf{find}{threads} || $cnf{find}{pages})
    {
        @deletion_posts = get_posts_by_regexp($proxy, $engine, $cnf{find});
    }
    else
    {
        Carp::croak("Should be specified how to find posts (by_id/threads/pages).");
    }

    for my $postid (@deletion_posts)
    {
        my $task = {
            proxy    => $proxy,
            board    => $cnf{board},
            password => $cnf{password},
            delete   => $postid,
        };
        $delete_queue->put($task);
    }
    #-------------------------------------------------------------------
    #-------------------------------------------------------------------
    #-- Timeout watcher
    my $tw = AnyEvent->timer(after => 0.5, interval => 1, cb =>
        sub
        {
            my @delete_coro  = grep { $_->desc eq 'delete' } Coro::State::list;

            echo_msg($LOGLEVEL >= 3, sprintf "run: %d; queue: %d", scalar @delete_coro, $delete_queue->size);

            for my $coro (@delete_coro)
            {
                my $now = Time::HiRes::time;
                if ($coro->{timeout_at} && $now > $coro->{timeout_at})
                {
                    echo_proxy(1, 'red', $coro->{proxy}, uc($coro->{desc}), '[TIMEOUT]');
                    $coro->cancel('timeout');
                }
            }
        }
    );

	#-- Delete watcher
    my $dw = AnyEvent->timer(after => 0.5, interval => 2, cb =>
        sub
        {
            my @delete_coro  = grep { $_->desc eq 'delete' } Coro::State::list;
            my $thrs_available = -1;
            #-- Max delete threads limit
            if ($cnf{max_del_thrs})
            {
                my $n = $cnf{max_del_thrs} - scalar @delete_coro;
                $thrs_available = $n > 0 ? $n : 0;
            }

            delete_post($engine, $delete_queue->get, \%cnf)
                while $delete_queue->size && $thrs_available--;
        }
    );

    #-- Exit watchers
    my $ew = AnyEvent->timer(after => 1, interval => 2, cb =>
        sub
        {
            my @delete_coro  = grep { $_->desc eq 'delete' } Coro::State::list;
            if (!@delete_coro && !$delete_queue->size)
            {
                EV::break;
                show_stats();
            }
        }
    );
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
