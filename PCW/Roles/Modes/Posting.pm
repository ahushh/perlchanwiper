package PCW::Roles::Modes::Posting;

use v5.12;
use Moo::Role;

# use AnyEvent;
# use Coro::State;
# use Coro::LWP;
# use Coro::Timer;
# use Time::HiRes;

use Coro;
use PCW::Core::Utils qw/with_coro_timeout/;

requires 'get_captcha_callback',
    'prepare_data_callback',
    'handle_captcha_callback',
    'make_post_callback';
#------------------------------------------------------------------------------------------------
sub get_captcha
{
    my ($self, $task) = @_;
    async {
        my $coro = $Coro::current;
        $coro->{task} = $task; ## используется для вывода подробных сообщений при таймауте
        $coro->desc('get_captcha');
        $coro->on_destroy($self->get_captcha_callback);

        my $status = 
        with_coro_timeout {
            $self->engine->get_captcha($task, $self->mode_config->{post_fields});
        } $coro, $self->mode_config->{timeout}{get_captcha};
        $coro->cancel($status, $task, $self);
    };
    cede;
}

sub prepare_data
{
    my ($self, $task) = @_;
    async {
        my $coro = $Coro::current;
        $coro->{task} = $task; 
        $coro->desc('prepare_data');
        $coro->on_destroy($self->prepare_data_callback);

        my $status =
        with_coro_timeout {
            $self->engine->prepare_data($task, $self->mode_config->{post_fields});
        } $coro, $self->mode_config->{timeout}{prepare_data};
        $coro->cancel($status, $task, $self);
    };
    cede;
}

sub handle_captcha
{
    my ($self, $task) = @_;
    async {
        my $coro = $Coro::current;
        $coro->{task} = $task;
        $coro->desc('handle_captcha');
        $coro->on_destroy($self->handle_captcha_callback);

        my $status =
        with_coro_timeout {
            $self->engine->handle_captcha($task, $self->mode_config->{post_fields});
        } $coro, $self->mode_config->{timeout}{handle_captcha};
        $coro->cancel($status, $task, $self);
    };
    cede;
}

sub make_post
{
    my ($self, $task) = @_;
    async {
        my $coro = $Coro::current;
        $coro->{task} = $task; 
        $coro->desc('make_post');
        $coro->on_destroy($self->make_post_callback);

        my $status =
        with_coro_timeout {
            $self->engine->make_post($task, $self->mode_config->{post_fields});
        } $coro, $self->mode_config->{timeout}{make_post};
        $coro->cancel($status, $task, $self);
    };
    cede;
}

1;
