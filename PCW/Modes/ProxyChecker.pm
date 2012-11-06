package PCW::Modes::ProxyChecker;

use v5.12;
use utf8;
use autodie;

use base 'PCW::Modes::Base';
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
use PCW::Core::Utils   qw/with_coro_timeout/;

#------------------------------------------------------------------------------------------------
# Local variables
#------------------------------------------------------------------------------------------------
my $queue        = {} ;
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
sub init($)
{
    my $self = shift;
    my $log  = $self->{log};
    $log->msg('MODE_STATE', "Initialization... ");
    $self->_base_init();
    $self->_init_base_watchers();
    $self->_run_custom_watchers($watchers, $queue);
    $self->_init_custom_watchers($watchers, $queue);
}

sub re_init_all_watchers($)
{
    my $self = shift;
    $_->cancel for (grep {$_->desc =~ /custom-watcher/ } Coro::State::list);
    for ( keys(%$watchers) )
    {
        $watchers->{$_} = undef;
    }
    $self->_init_base_watchers();
    $self->_run_custom_watchers($watchers, $queue);
    $self->_init_custom_watchers($watchers, $queue);
}

sub start($)
{
    my $self = shift;
    my $log  = $self->{log};
    return unless $self->{is_running};
    $log->msg('MODE_STATE', "Starting proxy checker mode...");
    async {
        $queue->{main}->put({ proxy => $_ }) for (@{ $self->{proxies} });
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
    $log->msg('MODE_STATE', "Stopping proxy checker mode...");
    $_->cancel for (grep {$_->desc =~ /custom-watcher|check/ } Coro::State::list);
    $watchers      = {};
    $queue->{main} = undef;

    my @g = @good_proxies;
    $self->{checked} = \@g;
    if ($self->{conf}{save} && @g)
    {
        local $" = "\n";
        open my $fh, '>', $self->{conf}{save};
        print $fh "@g";
        close $fh;
        $log->msg('PC_SAVE_PROXIES', "Saving good proxies to $self->{conf}{save}");
    }
    $self->{is_running} = 0;
}

sub _base_init($)
{
    my $self = shift;
    $self->{is_running} = 1;
    $self->{stats}      = {bad => 0, good => 0, total => 0};
    $self->{checked}    = {};
    $queue->{main}      = Coro::Channel->new();
}

sub _init_base_watchers($)
{
    my $self = shift;
    my $log = $self->{log};
    #-- Timeout watcher
    $watchers->{timeout} =
        AnyEvent->timer(after => 0.5, interval => 1, cb =>
                        sub
                        {
                            my @coros = grep { $_->desc eq 'check' } Coro::State::list;
                            for my $coro (@coros)
                            {
                                my $now = Time::HiRes::time;
                                if ($coro->{timeout_at} && $now > $coro->{timeout_at})
                                {
                                    $log->pretty_proxy('MODE_TIMEOUT', 'red', $coro->{task}{proxy}, uc($coro->{desc}), '[TIMEOUT]');
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
                              $self->check($queue->{main}->get)
                                  while $queue->{main}->size && $thrs_available--;
                          }
                         );

    #-- Exit watchers
    $watchers->{exit}
        = AnyEvent->timer(after => 5, interval => 1, cb =>
                          sub
                          {
                              my @checker_coro = grep { $_->desc =~ /check/ } Coro::State::list;
                              if (!(scalar @checker_coro) && $queue->{main}->size == 0)
                              {
                                  $self->stop;
                              }
                          }
                         );
}

1;
