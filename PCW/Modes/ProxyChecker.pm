package PCW::Modes::ProxyChecker;
 
use strict;
use autodie;
use Carp;
 
#------------------------------------------------------------------------------------------------
# Package Variables
#------------------------------------------------------------------------------------------------
our $LOGLEVEL   = 0;
our $VERBOSE = 0;
 
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
use PCW::Core::Log     qw(echo_msg echo_proxy);
use PCW::Core::Utils   qw(with_coro_timeout);
use PCW::Core::Captcha qw(captcha_report_bad);
 
#------------------------------------------------------------------------------------------------
# Local package variables and procedures
#------------------------------------------------------------------------------------------------
my @good_proxis;
my $queue = Coro::Channel->new();
my %stats = (bad => 0, good => 0, total => 0);

sub show_stats
{
    print "\nGood: $stats{good}\n";
    print "Bad: $stats{bad}\n";
    print "Total: $stats{total}\n";
    print "Proxies: @good_proxis\n";
};

#------------------------------------------------------------------------------------------------
#---------------------------------------  CHECK  -------------------------------------------------
#------------------------------------------------------------------------------------------------
my $cb_check = sub
{
    my ($msg, $task, $cnf) = @_;
    #-- Delete temporary files
    unlink($task->{file_path})
        if $cnf->{img_data}{altering} && $task->{file_path} && -e $task->{file_path};

    $stats{total}++;
    if ($msg =~ /wrong_captcha|flood|file_exist|unknown/) 
    {
        $stats{good}++;
        push @good_proxis, $task->{proxy}; 
    }
    else
    {
        $stats{bad}++;
    }
};

sub check($$$)
{
    my ($engine, $task, $cnf) = @_;
    async {
        my $coro = $Coro::current;
        $coro->desc('check');
        $coro->{proxy} = $task->{proxy}; #-- Для вывода timeout
        $coro->on_destroy($cb_check);

        # $engine->prepare($task, $cnf);

        my $status = 
        with_coro_timeout {
            $engine->ban_check($task, $cnf);
        } $coro, $cnf->{timeout};

        $coro->cancel($status, $task, $cnf);
    };
    cede;
}
#------------------------------------------------------------------------------------------------
#------------------------------------  MAIN CHECKER  --------------------------------------------
#------------------------------------------------------------------------------------------------
sub checker($$%)
{
    my ($self, $engine, %cnf) =  @_;

    #-- Initialization
    $queue->put({ proxy => $_ }) for (@{ $cnf{proxies} });

    #-- Timeout watcher
    my $tw = AnyEvent->timer(after => 0.5, interval => 1, cb =>
        sub
        {
            my @checker_coro = grep { $_->desc eq 'check' } Coro::State::list;

            echo_msg($LOGLEVEL >= 2, sprintf "run: %d coros.", scalar @checker_coro);
            echo_msg($LOGLEVEL >= 2, sprintf "queue: %d coros.", $queue->size);

            for my $coro (@checker_coro)
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

    #-- Watcher
    my $w = AnyEvent->timer(after => 0.5, interval => 1, cb =>
        sub
        {
            my @checker_coro = grep { $_->desc eq 'check' } Coro::State::list;
            my $thrs_available = $cnf{max_thrs} - scalar @checker_coro;
            check($engine, $queue->get, \%cnf)
                while $queue->size && $thrs_available--;
        }
    );
     
    #-- Exit watchers
    my $ew = AnyEvent->timer(after => 5, interval => 1, cb =>
        sub
        {
            my @checker_coro = grep { $_->desc =~ /check/ } Coro::State::list;
            if (!(scalar @checker_coro))
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
