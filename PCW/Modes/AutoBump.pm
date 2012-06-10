package PCW::Modes::AutoBump;

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
use PCW::Core::Utils   qw/with_coro_timeout/;
use PCW::Core::Captcha qw/captcha_report_bad/;

#------------------------------------------------------------------------------------------------
# Local variables
#------------------------------------------------------------------------------------------------
#-- Время следующего бампа
my $run_at       ;
my $queue    = {};
my $watchers = {};
#------------------------------------------------------------------------------------------------
# sub new($%)
# {
# }
#------------------------------------------------------------------------------------------------
#--------------------------------------  BUMP THREAD  -------------------------------------------
#------------------------------------------------------------------------------------------------
my $run_cleanup = unblock_sub
{
    my ($engine, $task, $self) = @_;
    my $log = $self->{log};
    $log->pretty_proxy(2, "green", $task->{proxy}, $task->{thread}, "Start deleting posts...");
    my @deletion_posts = $self->get_posts_by_regexp($task->{proxy}, $self->{conf}{silent}{find});

    $log->msg(4, "run_cleanup(): \@deletion_posts: @deletion_posts");

    for my $postid (@deletion_posts)
    {
        my $task = {
            proxy    => $task->{proxy},
            board    => $self->{silent}{conf}{board},
            password => $self->{silent}{conf}{password},
            delete   => $postid,
        };
        $queue->{delete}->put($task);
    }
};

#-- Coro callback
my $cb_bump_thread = unblock_sub
{
    my ($msg, $task, $self) = @_;
    my $log = $self->{log};
    $log->msg(4, "cb_bump_thread(): message: $msg");
    #-- Delete temporary files
    unlink($task->{path_to_captcha})
        if !$self->{conf}{save_captcha} && $task->{path_to_captcha} && -e $task->{path_to_captcha};
    unlink($task->{file_path})
        if $self->{conf}{img_data}{altering} && $task->{file_path} && -e $task->{file_path};

    $self->{stats}{bump}{total}++;
    if ($msg eq 'success')
    {
        $self->{stats}{bump}{bumped}++;

        my $now = Time::HiRes::time;
        $run_at = $now + $self->{conf}{interval};
        $log->pretty_proxy(2, "green", $task->{proxy}, "No. ". $task->{thread}, "sleep $self->{conf}{interval} seconds...");

        $log->msg(4, "run_cleanup(): try to start");
        &$run_cleanup($self, $task, $self) if ($self->{conf}{silent});
    }
    elsif ($msg =~ /wrong_captcha|no_captcha/)
    {
        $self->{stats}{bump}{error}++;
        captcha_report_bad($self->{conf}{captcha_decode}, $task->{path_to_captcha});
    }
    elsif ($msg eq 'wait')
    {
        $self->{stats}{bump}{wait}++;
        my $now = Time::HiRes::time;
        $run_at = $now + $self->{conf}{interval};
        $log->pretty_proxy(2, "green", $task->{proxy}, "No. ". $task->{thread}, "sleep $self->{conf}{interval} seconds...");
    }
    else
    {
        # может сделать смену прокси?
    }
    $queue->{bump}->put($task);
};

sub is_need_to_bump($$)
{
    my ($self, $task) = @_;
    my $engine = $self->{engine};
    my $log    = $self->{log};
    my %check_cnf = ( proxy => $task->{proxy}, board => $self->{conf}{post_cnf}{board}, thread => $task->{thread} );
    if ($self->{conf}{bump_if}{on_pages})
    {
        $log->pretty_proxy(1, "green", $task->{proxy}, "No. ". $task->{thread}, "Checking whether thread needs to bump...");
        my @pages = @{ $self->{conf}{bump_if}{on_pages} };
        for my $page (@pages)
        {
            $check_cnf{page} = $page;
            my $is_it = $engine->is_thread_on_page(%check_cnf);
            if ($is_it)
            {
                $log->pretty_proxy(1, "green", $task->{proxy}, "No. ". $task->{thread}, "Thread needs to be bumped!");
                return 1;
            }
        }
        $log->pretty_proxy(1, "green", $task->{proxy}, "No. ". $task->{thread}, "Thread doesn't need to bump");
        return undef;
    }
    elsif ($self->{conf}{bump_if}{not_on_pages})
    {
        $log->pretty_proxy(1, "green", $task->{proxy}, "No. ". $task->{thread}, "Checking whether thread needs to bump...");
        my @pages = @{ $self->{conf}{bump_if}{not_on_pages} };
        for my $page (@pages)
        {
            $check_cnf{page} = $page;
            my $is_it = $engine->is_thread_on_page(%check_cnf);
            if ($is_it)
            {
                $log->pretty_proxy(1, "green", $task->{proxy}, "No. ". $task->{thread}, "Thread doesn't need to bump");
                return undef;
            }
        }
        $log->pretty_proxy(1, "green", $task->{proxy}, "No. ". $task->{thread}, "Thread needs to be bumped!");
        return 1;
    }
}

sub bump_thread($$)
{
    my ($self, $task) = @_;
    my $engine = $self->{engine};
    async {
        my $coro = $Coro::current;
        $coro->desc('bump');
        $coro->{task} = $task;
        $coro->on_destroy($cb_bump_thread);
        $coro->cancel('wait', $task, $self)
            unless is_need_to_bump($self, $task);
        my $status =
        with_coro_timeout {
            my $status = $engine->get($task, $self->{conf});
            $coro->cancel($status, $task, $self) if ($status ne 'success');

            $status = $engine->prepare($task, $self->{conf});
            $coro->cancel($status, $task, $self) if ($status ne 'success');

            $status = $engine->post($task, $self->{conf});
        } $coro, $self->{conf}{timeout};
        $coro->cancel($status, $task, $self);
    };
    cede;
}

#------------------------------------------------------------------------------------------------
#--------------------------------------  DELETE BUMP  -------------------------------------------
#------------------------------------------------------------------------------------------------
#-- Coro callback
my $cb_delete_post = unblock_sub
{
    my ($msg, $task, $self) = @_;
    $self->{stats}{delete}{total}++;
    given ($msg)
    {
        when ('success')
        {
            $self->{stats}{delete}{deleted}++;
        }
        when ('wrong_password')
        {
            $self->{stats}{delete}{wrong_password}++;
        }
        default
        {
            $self->{stats}{delete}{error}++;
        }
    }
};

sub delete_post($$)
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
            $engine->delete($task, $self->{conf}{silent});
        } $coro, $self->{conf}{silent}{delete_timeout};
        $coro->cancel($status, $task, $self);
    };
    cede;
}

#------------------------------------------------------------------------------------------------
#---------------------------------------  BUMP MAIN  --------------------------------------------
#------------------------------------------------------------------------------------------------
sub init($)
{
    my $self = shift;
    my $log  = $self->{log};
    $log->msg(1, "Initialization... ");
    $self->_base_init();
    $self->_init_watchers();
    $self->_run_custom_watchers($watchers, $queue);
    $self->_init_custom_watchers($watchers, $queue);
}

sub start($)
{
    my $self = shift;
    my $log  = $self->{log};
    $log->msg(1, "Starting autobump mode...");
    async {
        my $proxy = shift @{ $self->{proxies} };
        $queue->{bump}->put({ proxy => $proxy, thread => $self->{conf}{post_cnf}{thread} });
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
    $log->msg(1, "Stopping autobump mode...");
    $_->cancel for (grep {$_->desc =~ /bump|delete/ } Coro::State::list);
    for ( (keys(%$watchers), keys(%$queue)) )
    {
        $watchers->{$_} = undef;
        $queue->{$_}    = undef;
    }
    $self->{is_running} = 0;
}

sub _base_init($)
{
    my $self      = shift;
    $run_at       = 0;
    $queue->{bump}   = Coro::Channel->new();
    $queue->{delete} = Coro::Channel->new();
    $self->{is_running}    = 1;
    $self->{stats}{bump}   = {error => 0, bumped  => 0, total => 0, wait           => 0};
    $self->{stats}{delete} = {error => 0, deleted => 0, total => 0, wrong_password => 0};

}

sub _init_watchers($)
{
    my $self = shift;
    my $log  = $self->{log};
    #-- Timeout watcher
    $watchers->{timeout} =
        AnyEvent->timer(after => 0.5, interval => 1, cb =>
                        sub
                        {
                            my @bump_coro   = grep { $_->desc ? ($_->desc eq 'bump')   : 0 } Coro::State::list;
                            my @delete_coro = grep { $_->desc ? ($_->desc eq 'delete') : 0 } Coro::State::list;

                            $log->msg(4, sprintf "run: %d bump, %d delete.",
                                     scalar @bump_coro, scalar @delete_coro);
                            $log->msg(4, sprintf "queue: %d bump, %d delete.",
                                     $queue->{bump}->size, $queue->{delete}->size);

                            for my $coro (@bump_coro, @delete_coro)
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

    #-- Bump watcher
    $watchers->{bump} =
        AnyEvent->timer(after => 0.5, interval => 1, cb =>
                        sub
                        {
                            my @bump_coro   = grep { $_->desc ? ($_->desc eq 'bump')   : 0 } Coro::State::list;
                            my @delete_coro = grep { $_->desc ? ($_->desc eq 'delete') : 0 } Coro::State::list;

                            #-- Ждем, если уже запущен бамп или удаление
                            return if (scalar @bump_coro or scalar @delete_coro);
                            my $now = Time::HiRes::time;
                            #-- Или если время еще не пришло
                            return if ($now < $run_at);
                            $self->bump_thread( $queue->{bump}->get );
                        }
                       );

    #-- Delete watcher
    $watchers->{delete} =
        AnyEvent->timer(after => 1, interval => 2, cb =>
                        sub
                        {
                            my @delete_coro = grep { $_->desc ? ($_->desc eq 'delete') : 0 } Coro::State::list;

                            my $thrs_available = -1;
                            #-- Max delete threads limit
                            if ($self->{conf}{silent}{max_del_thrs})
                            {
                                my $n = $self->{conf}{silent}{max_del_thrs} - scalar @delete_coro;
                                $thrs_available = $n > 0 ? $n : 0;
                            }

                            $self->delete_post($queue->{delete}->get)
                                while $queue->{delete}->size && $thrs_available--;
                        }
                       ) if $self->{conf}{silent};
}

1;
