package PCW::Modes::Delete;

use v5.12;
use utf8;

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
use PCW::Core::Net   qw/http_get/;
use PCW::Core::Utils qw/with_coro_timeout get_posts_ids/;

#------------------------------------------------------------------------------------------------
# Local variables
#------------------------------------------------------------------------------------------------
my $queue    = {};
my $watchers = {};

#------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------
# sub new($%)
# {
# }
#------------------------------------------------------------------------------------------------
#----------------------------------  DELETE POST  -----------------------------------------------
#------------------------------------------------------------------------------------------------
#-- Coro callback
my $cb_delete_post = unblock_sub
{
    my ($msg, $task, $self) = @_;
    my $log = $self->{log};
    $self->{stats}{total}++;
    given ($msg)
    {
        when ('success')
        {
            $self->{stats}{deleted}++;
        }
        when ('wrong_password')
        {
            $self->{stats}{wrong_password}++;
        }
        default
        {
            $self->{stats}{error}++;
            my $errors = $self->{stats}{error};
            my $limit  = $self->{conf}{attempts};
            if ($limit < 0 or $errors < $limit)
            {
                $queue->{delete}->put($task);
                $log->pretty_proxy('MODE_CB', 'red', $task->{proxy}, 'DELETE '.$task->{delete}, "$msg: try again ($errors/$limit)");
            }
        }
    }
};

sub delete_post($$$)
{
    my ($self, $task) = @_;
    my $engine = $self->{engine};
    async {
        my $coro = $Coro::current;
        $coro->desc('delete');
        $coro->{task} = $task;
        $coro->on_destroy($cb_delete_post);
        my $status =
        with_coro_timeout {
            $engine->delete($task, $self->{conf});
        } $coro, $self->{conf}{delete_timeout};
        $coro->cancel($status, $task, $self);
    };
    cede;
}

#------------------------------------------------------------------------------------------------
#------------------------------------  MAIN DELETE  ---------------------------------------------
#------------------------------------------------------------------------------------------------
sub init($)
{
    my $self = shift;
    my $log  = $self->{log};
    $log->msg('MODE_STATE', "Initialization... ");
    $self->_base_init();
    $self->_run_custom_watchers($watchers, $queue);
    $self->_init_base_watchers();
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
    $self->_init_custom_watchers($watchers, $queue);
}

sub start($)
{
    my $self = shift;
    my $log  = $self->{log};
    return unless $self->{is_running};
    $log->msg('MODE_STATE', "Starting delete mode...");
    async {
        #-------------------------------------------------------------------
        my $proxy = shift @{ $self->{proxies} };
        $log->msg('DEL_SHOW_PROXY', "Used proxy: $proxy");
        my @deletion_posts = @{ $self->{conf}{ids} };
        if ($self->{conf}{find})
        {
            my $c = async {
                my $coro = $Coro::current;
                $coro->desc('custom-watcher');
                @deletion_posts =  ( @deletion_posts,
                                     get_posts_ids($self->{engine}, $proxy, $self->{conf}{find}) );
            };
            $c->join();
        }
        for my $postid (@deletion_posts)
        {
            my $task = {
                        proxy    => $proxy,
                        board    => $self->{conf}{board},
                        password => $self->{conf}{password},
                        delete   => $postid,
                       };
            $queue->{delete}->put($task);
        }
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
    $log->msg('MODE_STATE', "Stopping delete mode...");
    $_->cancel for (grep {$_->desc =~ /custom-watcher|delete/ } Coro::State::list);
    for ( (keys(%$watchers), keys(%$queue)) )
    {
        $watchers->{$_} = undef;
        $queue->{$_}    = undef;
    }
    $self->{is_running} = 0;
}

sub _base_init($)
{
    my $self = shift;
    $self->{is_running} = 1;
    $self->{stats}      = {error => 0, wrong_password => 0, deleted => 0, total => 0};
    $queue->{delete}    = Coro::Channel->new();
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
                            my @delete_coro  = grep { $_->desc eq 'delete' } Coro::State::list;
                            for my $coro (@delete_coro)
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

    #-- Delete watcher
    $watchers->{delete}
        = AnyEvent->timer(after => 0.5, interval => 2, cb =>
        sub
        {
            my @delete_coro  = grep { $_->desc eq 'delete' } Coro::State::list;
            my $thrs_available = -1;
            #-- Max delete threads limit
            if ($self->{conf}{max_del_thrs})
            {
                my $n = $self->{conf}{max_del_thrs} - scalar @delete_coro;
                $thrs_available = $n > 0 ? $n : 0;
            }

            $self->delete_post($queue->{delete}->get)
                while $queue->{delete}->size && $thrs_available--;
        }
    );

    #-- Exit watchers
    $watchers->{exit} =
        AnyEvent->timer(after => 10, interval => 2, cb =>
        sub
        {
            my @delete_coro  = grep { $_->desc eq 'delete'         } Coro::State::list;
            my @custom_coro  = grep { $_->desc eq 'custom-watcher' } Coro::State::list;
            if (!@delete_coro && !@custom_coro && !$queue->{delete}->size)
            {
                $self->stop;
            }
        }
    );
}

1;
