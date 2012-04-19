package PCW::Modes::ProxyChecker;

use strict;
use autodie;
use Carp;
use feature qw(say);

use base 'PCW::Modes::Abstract';
#------------------------------------------------------------------------------------------------
# Importing Coro packages
#------------------------------------------------------------------------------------------------
use AnyEvent;
use Coro::State;
use Coro::LWP;
use Coro::Timer;
use Coro;
use Time::HiRes;

#------------------------------------------------------------------------------------------------
# Importing internal PCW packages
#------------------------------------------------------------------------------------------------
use PCW::Core::Utils   qw(with_coro_timeout);
use PCW::Core::Captcha qw(captcha_report_bad);

#------------------------------------------------------------------------------------------------
# Local variables
#------------------------------------------------------------------------------------------------
my $queue             ;
my $watchers     = {} ;
my @good_proxies = () ;
#------------------------------------------------------------------------------------------------
# sub new($%)
# {
# }
#------------------------------------------------------------------------------------------------
#---------------------------------------  CHECK  -------------------------------------------------
#------------------------------------------------------------------------------------------------
my $cb_check = unblock_sub
{
    my ($msg, $task, $self) = @_;
    #-- Delete temporary files
    unlink($task->{file_path})
        if $self->{conf}{img_data}{altering} && $task->{file_path} && -e $task->{file_path};

    $self->{stats}{total}++;
    if ($msg =~ /banned|critical_error|net_error|unknown|timeout/)
    {
        $self->{stats}{bad}++;
    }
    else
    {
        $self->{stats}{good}++;
        push @good_proxies, $task->{proxy};
    }
};

sub check($$$)
{
    my ($self, $task) = @_;
    my $engine = $self->{engine};
    async {
        my $coro = $Coro::current;
        $coro->desc('check');
        $coro->{task} = $task;
        $coro->on_destroy($cb_check);

        my $status = 
        with_coro_timeout {
            $engine->ban_check($task, $self->{conf});
        } $coro, $self->{conf}{timeout};

        $coro->cancel($status, $task, $self);
    };
    cede;
}
#------------------------------------------------------------------------------------------------
#------------------------------------  MAIN CHECKER  --------------------------------------------
#------------------------------------------------------------------------------------------------
sub start($)
{
    my $self = shift;
    my $log  = $self->{log};
    $log->msg(1, "Starting proxy checker mode...");
    async {
        $self->_pre_init();
        $queue->put({ proxy => $_ }) for (@{ $self->{proxies} });
        $self->_init_watchers();
        while ($self->{is_running})
        {
            Coro::Timer::sleep 1;
        }
    };
    cede;
}

sub stop($)
{
    my $self = shift;
    my $log  = $self->{log};
    $log->msg(1, "Stopping proxy checker mode...");
    $_->cancel for (grep {$_->desc =~ /check/ } Coro::State::list);
    $watchers = {};
    $queue    = undef;
    $self->{is_running} = 0;
    my @g = @good_proxies;
    $self->{checked}    = \@g;
}

sub _pre_init($)
{
    my $self = shift;
    $self->{is_running} = 1;
    $self->{stats}      = {bad => 0, good => 0, total => 0};
    $self->{checked}    = {};
    $queue              = Coro::Channel->new();
}

sub _init_watchers($)
{
    my $self = shift;
    my $log = $self->{log};
    #-- Timeout watcher
    $watchers->{timeout} =
        AnyEvent->timer(after => 0.5, interval => 1, cb =>
                        sub
                        {
                            my @coros = grep { $_->desc eq 'check' } Coro::State::list;
                            $log->msg(3, sprintf "run: %d; queue: %d", scalar(@coros), $queue->size);

                            for my $coro (@coros)
                            {
                                my $now = Time::HiRes::time;
                                if ($coro->{timeout_at} && $now > $coro->{timeout_at})
                                {
                                    $log->pretty_proxy(1, 'red', $coro->{task}{proxy}, uc($coro->{desc}), '[TIMEOUT]');
                                    $coro->cancel('timeout', $coro->{task}, $self);
                                }
                            }
                        }
                       );

    #-- Watcher
    $watchers->{check}
        = AnyEvent->timer(after => 0.5, interval => 1, cb =>
                          sub
                          {
                              my @checker_coro = grep { $_->desc eq 'check' } Coro::State::list;
                              my $thrs_available = $self->{conf}{max_thrs} - scalar @checker_coro;
                              $self->check($queue->get)
                                  while $queue->size && $thrs_available--;
                          }
                         );

    #-- Exit watchers
    $watchers->{exit}
        = AnyEvent->timer(after => 5, interval => 1, cb =>
                          sub
                          {
                              my @checker_coro = grep { $_->desc =~ /check/ } Coro::State::list;
                              if (!(scalar @checker_coro) && $queue->size == 0)
                              {
                                  $self->stop;
                              }
                          }
                         );
}

1;
