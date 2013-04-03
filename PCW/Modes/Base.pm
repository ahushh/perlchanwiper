package PCW::Modes::Base;

use v5.12;
use utf8;
use Moo;
use Carp qw/croak/;

use PCW::Core::Utils qw/took curry/;
use Data::Random     qw/rand_set/;

use AnyEvent;
use Coro::State;
use Coro::LWP;
use Coro::Timer;
use Coro;
use Time::HiRes;
#------------------------------------------------------------------------------------------------
has 'engine' => (
    is       => 'rw',
    required => 1,
);

has 'proxies' => (
    is        => 'rw',
    default   => sub { ['http://no_proxy'] },
);

has 'mode_config' => (
    is          => 'rw',
    required    => 1,
);

has 'log' => (
    is       => 'rw',
    required => 1,
);

has 'verbose' => (
    is      => 'rw',
    default => sub { 0 },
);
#------------------------------------------------------------------------------------------------
has 'watchers' => (
    is => 'rw',
    is      => 'rw',
    default => sub { {} },
);

has 'coro_queue' => (
    is      => 'rw',
    default => sub { {} },
);

has 'is_running' => (
    is      => 'rw',
    default => sub { 0 },
);

has 'go_to_bed_callback' => (
    is      => 'rw',
);
#------------------------------------------------------------------------------------------------
sub _run_custom_watchers
{
    my ($self, $queue) = @_;
    while ( my ($name, $wt) = each %{ $self->mode_config->{watchers} } )
    {
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

sub _init_custom_watchers
{
    my ($self, $queue) = @_;
    while ( my ($name, $wt) = each %{ $self->mode_config->{watchers} } )
    {
        next unless $wt->{enable};
        given ($wt->{type})
        {
            when ('timer')
            {
                $self->watchers->{$name} =
                    AnyEvent->timer(after    => $wt->{after},
                                    interval => $wt->{interval},
                                    cb       => curry( $wt->{cb}, $self, $wt->{conf}, $queue ),
                                   ) if $wt->{on_start} != 2;
            }
         }
    }
}

# sub reinit_watchers
# {
#     my $self = shift;
#     $_->cancel for Coro::State::list;
#     for ( keys(%{ $self->watchers }) )
#     {
#         $self->watchers->{$_} = undef;
#     }
#     $self->_init_base_watchers();
#     $self->_run_custom_watchers($self->watchers, $queue);
#     $self->_init_custom_watchers($self->watchers, $queue);
# }

sub go_to_bed
{
    my ($self, $task) = @_;
    async {
        my $coro = $Coro::current;
        $coro->desc('sleep');
        $self->log->pretty_proxy('MODE_SLEEP', 'green', $task->{proxy}, 'SLEEP', "sleep $task->{time} seconds");
        my $now = Time::HiRes::time;
        # Coro::Timer::sleep( int($task->{run_at} - $now) );
        $coro->cancel('success', $task, $self);
    };
    cede;
}
#------------------------------------------------------------------------------------------------
sub init
{
    my $self = shift;
    $self->log->msg('MODE_STATE', "Initialization... ");
    $self->_base_init();
    $self->_init_base_watchers();
    $self->_run_custom_watchers();
    $self->_init_custom_watchers();
}

sub stop
{
    my $self = shift;
    $self->log->msg('MODE_STATE', "Stopping...");
    $_->cancel for (grep {$_->desc =~ /custom-watcher|get_captcha|prepare_data|make_post|sleep|handle_captcha/ } Coro::State::list);
    $self->watchers->{$_}   = undef for (keys %{ $self->watchers });
    $self->coro_queue->{$_} = undef for (keys %{ $self->coro_queue });
    $self->is_running(0);
}

1;
