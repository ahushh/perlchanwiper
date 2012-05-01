package PCW::Modes::Delete;

use strict;
use autodie;
use Carp;
use feature qw(switch say);

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
use PCW::Core::Net   qw(http_get);
use PCW::Core::Utils qw(with_coro_timeout);

#------------------------------------------------------------------------------------------------
# Local variables
#------------------------------------------------------------------------------------------------
my $delete_queue;
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
sub start($)
{
    my $self = shift;
    my $log  = $self->{log};
    $log->msg(1, "Starting delete mode...");
    async {
        $self->_pre_init();
        #-------------------------------------------------------------------
        my $proxy = shift @{ $self->{proxies} };
        $log->msg(2, "Used proxy: $proxy");
        my @deletion_posts;
        if ($self->{conf}{find}{by_id})
        {
            @deletion_posts = @{ $self->{conf}{find}{by_id} };
        }
        elsif ($self->{conf}{find}{threads} || $self->{conf}{find}{pages})
        {
            @deletion_posts = $self->get_posts_by_regexp($proxy, $self->{conf}{find});
        }
        else
        {
            Carp::croak("Should be specified how to find posts (by_id/threads/pages).");
        }
        for my $postid (@deletion_posts)
        {
            my $task = {
                        proxy    => $proxy,
                        board    => $self->{conf}{board},
                        password => $self->{conf}{password},
                        delete   => $postid,
                       };
            $delete_queue->put($task);
        }
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
    $log->msg(1, "Stopping delete mode...");
    $_->cancel for (grep {$_->desc =~ /delete/ } Coro::State::list);
    $watchers     = {};
    $delete_queue = undef;
    $self->{is_running} = 0;
}

sub _pre_init($)
{
    my $self = shift;
    $self->{is_running} = 1;
    $self->{stats}      = {error => 0, wrong_password => 0, deleted => 0, total => 0};
    $delete_queue       = Coro::Channel->new();
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
                            my @delete_coro  = grep { $_->desc eq 'delete' } Coro::State::list;
                            $log->msg(4, sprintf "run: %d; queue: %d", scalar @delete_coro, $delete_queue->size);
                            for my $coro (@delete_coro)
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

            $self->delete_post($delete_queue->get)
                while $delete_queue->size && $thrs_available--;
        }
    );

    #-- Exit watchers
    $watchers->{exit} =
        AnyEvent->timer(after => 1, interval => 2, cb =>
        sub
        {
            my @delete_coro  = grep { $_->desc eq 'delete' } Coro::State::list;
            if (!@delete_coro && !$delete_queue->size)
            {
                $self->stop;
            }
        }
    );
}

1;
