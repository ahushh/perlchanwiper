package PCW::Modes::Base;

use v5.12;
use utf8;
use Carp;

use PCW::Core::Utils qw/took curry/;
use Data::Random     qw/rand_set/;

use AnyEvent;
use Coro::State;
use Coro::LWP;
use Coro::Timer;
use Coro;
use Time::HiRes;
#------------------------------------------------------------------------------------------------
sub new($%)
{
    my ($class, %args) = @_;
    my $engine   = delete $args{engine};
    my $proxies  = delete $args{proxies};
    my $conf     = delete $args{conf};
    my $log      = delete $args{log};
    my $verbose  = delete $args{verbose} || 0;

    my @k = keys %args;
    Carp::croak("These options aren't defined: @k")
        if %args;

    my $self = {};
    $self->{engine}  = $engine;
    $self->{proxies} = $proxies;
    $self->{conf}    = $conf;
    $self->{log}     = $log;
    $self->{verbose} = $verbose;
    bless $self, $class;
}
#------------------------------------------------------------------------------------------------
sub _run_custom_watchers($$$)
{
    my ($self, $watchers, $queue) = @_;
    for my $name (keys %{ $self->{conf}{watchers} })
    {
        my $wt = $self->{conf}{watchers}{$name};
        next unless $wt->{enable};
        if ($wt->{on_start})
        {
            my $cb = $wt->{cb};
            &$cb($self, $wt->{conf}, $queue);
        }
    }
    while (grep {$_->desc eq 'custom-watcher' } Coro::State::list)
    {
        Coro::Timer::sleep 1;
    }
}

sub _init_custom_watchers($$$)
{
    my ($self, $watchers, $queue) = @_;
    for my $name (keys %{ $self->{conf}{watchers} })
    {
        my $wt = $self->{conf}{watchers}{$name};
        next unless $wt->{enable};
        given ($wt->{type})
        {
            when ('timer')
            {
                $watchers->{$name} =
                    AnyEvent->timer(after    => $wt->{after},
                                    interval => $wt->{interval},
                                    cb       => curry( $wt->{cb}, $self, $wt->{conf}, $queue ),
                                   ) if $wt->{on_start} != 2;
            }
         }
    }
}

1;
