package PCW::Modes::Bump;

use strict;
use autodie;
use Carp;
 
#------------------------------------------------------------------------------------------------
# Package Variables
#------------------------------------------------------------------------------------------------
our $CAPTCHA_DIR = './captcha';
our $DEBUG   = 0;
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
# Importing utility packages
#------------------------------------------------------------------------------------------------
use File::Basename;
use File::Copy qw(move);
 
#------------------------------------------------------------------------------------------------
# Importing internal PCW packages
#------------------------------------------------------------------------------------------------
use PCW::Core::Log qw(echo_msg echo_msg_dbg echo_proxy echo_proxy_dbg);
use PCW::Utils     qw(with_coro_timeout);
use PCW::Captcha   qw(captcha_report_bad);
 
#------------------------------------------------------------------------------------------------
# Local package variables and procedures
#------------------------------------------------------------------------------------------------
my $queue = Coro::Channel->new();
my %stats = (error => 0, bumped => 0, total => 0);

my $run_at = 0;
my @proxies;
 
sub show_stats
{
    print "\nBumped: $stats{bumped}\n";
    print "Error: $stats{error}\n";
    print "Total: $stats{total}\n";
};

#------------------------------------------------------------------------------------------------
#--------------------------------------  BUMP THREAD  -------------------------------------------
#------------------------------------------------------------------------------------------------
#-- Coro callback
my $cb_bump_thread = sub
{ 
    my ($msg, $task, $chan, $cnf) = @_;
    echo_msg_dbg($DEBUG > 1, "cb_bump_thread(): message: $msg");
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
        $run_at = $now + $cnf->{time};
        #-- добавить в task что нужно засыпать
    }
    elsif ($msg eq 'wrong_captcha')
    {
        $stats{error}++;
    }
    else #-- Меняем прокси на следующую
    {
        #---- !!!???????????!??????????!? FIX IT
        my $proxy = shift @proxies;
        $task->{proxy} = $proxy;
        unless ($task->{proxy})
        {
            echo_msg("All proxies are dead");
            EV::break;
            show_stats();
            exit;
        }
    }
    $queue->put($task);
};

sub bump_thread($$$$)
{
    my ($engine, $task, $chan, $cnf) = @_;
    async {
        my $coro = $Coro::current;
        $coro->desc('bump');
        $coro->{proxy} = $task->{proxy}; #-- Для вывода timeout
        $coro->on_destroy($cb_bump_thread);
        my $status = 
        with_coro_timeout {
            my $status = $engine->get($task, $chan, $cnf);
            $coro->cancel($status, $task, $chan, $cnf) if ($status ne 'success');
             
            $status = $engine->prepare($task, $chan, $cnf);
            $coro->cancel($status, $task, $chan, $cnf) if ($status ne 'success');
             
            $status = $engine->post($task, $chan, $cnf);
            
        } $coro, $cnf->{timeout};
        $coro->cancel($status, $task, $chan, $cnf);
    };
    cede;
}

#------------------------------------------------------------------------------------------------
#--------------------------------------  DELETE BUMP  -------------------------------------------
#------------------------------------------------------------------------------------------------
#-- Coro callback
#my $cb_delete_bump = sub
#{
    #my ($msg, $task, $chan, $cnf) = @_;
#}

#sub delete_bump($$$$)
#{
    #my ($engine, $task, $chan, $cnf) = @_;
#}
 
#------------------------------------------------------------------------------------------------
#---------------------------------------  BUMP MAIN  --------------------------------------------
#------------------------------------------------------------------------------------------------
sub bump($$%)
{
    my ($self, $engine, $chan, %cnf) =  @_;
     
    #-- Initialization
    @proxies = @{ $cnf{proxies} };
    my $proxy = shift @proxies;
    $queue->put({ proxy => $proxy });

    #-- Timeout watcher
    my $tw = AnyEvent->timer(after => 0.5, interval => 1, cb =>
        sub
        {
            my @bump_coro   = grep { $_->desc =~ /bump/   } Coro::State::list;
            my @delete_coro = grep { $_->desc =~ /delete/ } Coro::State::list;

            for my $coro (@bump_coro, @delete_coro)
            {
                my $now = Time::HiRes::time;
                if ($coro->{timeout_at} && $now > $coro->{timeout_at})
                {
                    echo_proxy('red', $coro->{proxy}, uc($coro->{desc}), '[TIMEOUT]');
                    $coro->cancel('timeout');
                }
            }
        }
    );

    #-- Main watcher
    my $mw = AnyEvent->timer(after => 0.5, interval => 1, cb =>
        sub
        {
            my @bump_coro   = grep { $_->desc =~ /bump/   } Coro::State::list;
            my @delete_coro = grep { $_->desc =~ /delete/ } Coro::State::list;
             
            my $now = Time::HiRes::time;
            echo_msg_dbg($DEBUG > 1, "now: $now");
            echo_msg_dbg($DEBUG > 1, "run at: $run_at");
            return unless ($queue->size); #-- может бамп уже запущен
             
            if ($now > $run_at)
            {
                my $task = $queue->get;
                echo_msg_dbg($DEBUG > 1, "bump_thread();");
                bump_thread($engine, $task, $chan, \%cnf);
                
                #delete_bump($engine, $task, $chan, $cnf{silent}) if ($cnf{silent});
            }
        }
    );

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
