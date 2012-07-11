package PCW::Modes::Wipe;

use v5.12;
use utf8;
use autodie;
use Carp;

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
# Importing utility packages
#------------------------------------------------------------------------------------------------
use FindBin    qw/$Bin/;
use File::Copy qw/move/;
use File::Spec;
use File::Basename;

#------------------------------------------------------------------------------------------------
# Importing internal PCW packages
#------------------------------------------------------------------------------------------------
use PCW::Core::Utils   qw/with_coro_timeout/;
use PCW::Core::Captcha qw/captcha_report_bad/;

#------------------------------------------------------------------------------------------------
# Package variables
#------------------------------------------------------------------------------------------------
our $CAPTCHA_DIR = File::Spec->catfile($Bin, 'captcha');

#------------------------------------------------------------------------------------------------
# Local variables
#------------------------------------------------------------------------------------------------
my $watchers  = {};
my $queue     = {};

#------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------
# sub new($%)
# {
# }
#------------------------------------------------------------------------------------------------
#-----------------------------------------  WIPE GET --------------------------------------------
#------------------------------------------------------------------------------------------------
#-- Coro callback
my $cb_wipe_get = unblock_sub
{
    my ($msg, $task, $self) = @_;
    return unless @_;

    given ($msg)
    {
        when ('success')
        {
            $queue->{prepare}->put($task);
        }
        when (/net_error|timeout/)
        {
            $self->{failed_proxy}{ $task->{proxy} }++;
        }
        default
        {
            $self->{failed_proxy}{ $task->{proxy} } = 0;
        }
    }
};

sub wipe_get($$)
{
    my ($self, $task) = @_;
    my $engine = $self->{engine};
    my $log    = $self->{log};
    async {
        my $coro = $Coro::current;
        $coro->desc('sleeping');
        $coro->{task} = $task;

        if ($task->{run_at})
        {
            my $now = Time::HiRes::time;
            $log->pretty_proxy(2, 'green', $task->{proxy}, 'GET',
                               sprintf("sleep %d...", $self->{conf}{flood_limit}));
            Coro::Timer::sleep( int($task->{run_at} - $now) );
        }

        $coro->desc('get');
        $coro->on_destroy($cb_wipe_get);

        my $status = 
        with_coro_timeout {
            $engine->get($task, $self->{conf});
        } $coro, $self->{conf}{get_timeout};
        $coro->cancel($status, $task, $self);
    };
    cede;
}

#------------------------------------------------------------------------------------------------
#--------------------------------------  WIPE PREPARE -------------------------------------------
#------------------------------------------------------------------------------------------------
#-- Coro callback
my $cb_wipe_prepare = unblock_sub
{
    my ($msg, $task, $self) = @_;
    return unless @_;
    my $log = $self->{log};

    given ($msg)
    {
        when ('success')
        {
            $queue->{post}->put($task);
        }
        when ('no_captcha')
        {
            my $new_task = {proxy => $task->{proxy} };
            $self->{failed_proxy}{ $task->{proxy} }++;
            if ($self->{conf}{wcap_retry} && $self->{failed_proxy}{ $task->{proxy} } < $self->{conf}{proxy_attempts})
            {
                $log->msg(4, "push into the get queue: $task->{proxy}");
                $queue->{get}->put($new_task);
            }
        }
        when (/net_error|timeout/)
        {
            $self->{failed_proxy}{ $task->{proxy} }++;
        }
        default
        {
            $self->{failed_proxy}{ $task->{proxy} } = 0;
        }
    }
};

sub wipe_prepare($$$)
{
    my ($self, $task) = @_;
    my $engine = $self->{engine};
    async {
        my $coro = $Coro::current;
        $coro->desc('prepare');
        $coro->{task} = $task;
        $coro->on_destroy($cb_wipe_prepare);
        my $status =
        with_coro_timeout {
            $engine->prepare($task, $self->{conf});
        } $coro, $self->{conf}->{prepare_timeout};
        $coro->cancel($status, $task, $self);
    };
    cede;
}

#------------------------------------------------------------------------------------------------
#----------------------------------------  WIPE POST  -------------------------------------------
#------------------------------------------------------------------------------------------------
#-- Coro callback
my $cb_wipe_post = unblock_sub
{
    my ($msg, $task, $self) = @_;
    return unless @_;
    my $log = $self->{log};

    #-- Delete temporary files
    unlink($task->{path_to_captcha})
        if !$self->{conf}{save_captcha} && $task->{path_to_captcha} && -e $task->{path_to_captcha};
    unlink($task->{file_path})
        if $self->{conf}{img_data}{altering} && $task->{file_path} && -e $task->{file_path};

    $self->{stats}{total}++;
    my $new_task = {};
    given ($msg)
    {
        when ('success')
        {
            #-- Move successfully recognized captcha into the specified dir
            if ($self->{conf}{save_captcha} && $task->{path_to_captcha})
            {
                my ($name, $path, $suffix) = fileparse($task->{path_to_captcha}, 'png', 'jpeg', 'jpg', 'gif');
                move $task->{path_to_captcha},
                    File::Spec->catfile($CAPTCHA_DIR, $task->{captcha_text} ."--". time .".$suffix");
            }
            $self->{stats}{posted}++;

            if ($self->{conf}{flood_limit} && $self->{conf}{loop})
            {
                my $now = Time::HiRes::time;
                $new_task->{run_at} = $now + $self->{conf}{flood_limit};
            }
        }
        when ('wrong_captcha')
        {
            $self->{stats}{wrong_captcha}++;
            captcha_report_bad($self->{conf}{captcha_decode}, $task->{path_to_captcha});
            if ($self->{conf}{wcap_retry})
            {
                $log->msg(4, "push into the get queue: $task->{proxy}");
                $new_task->{proxy} = $task->{proxy};
                $queue->{get}->put($new_task);
                return;
            }
        }
        when ('critical_error')
        {
            $log->msg(1, "Critical chan error has occured!", '', 'red');
            $queue->{get}->put($new_task);
        }
        when ('flood')
        {
            $self->{stats}{error}++;
            if ($self->{conf}{flood_limit} && $self->{conf}{loop})
            {
                my $now = Time::HiRes::time;
                $new_task->{run_at} = $now + $self->{conf}{flood_limit};
            }
        }
        default
        {
            $self->{stats}{error}++;
        }
    }

    if ($msg =~ /net_error|timeout/)
    {
        $self->{failed_proxy}{ $task->{proxy} }++;
    }
    else
    {
        $self->{failed_proxy}{ $task->{proxy} } = 0;
    }

    if ($self->{conf}{loop} && $msg ne 'banned' &&
        $self->{failed_proxy}{ $task->{proxy} } < $self->{conf}{proxy_attempts})
    {
        $log->msg(4, "push into the get queue: $task->{proxy}");
        $new_task->{proxy} = $task->{proxy};
        $queue->{get}->put($new_task);
    }
};

sub wipe_post($$$)
{
    my ($self, $task) = @_;
    my $engine = $self->{engine};
    async {
        my $coro = $Coro::current;
        $coro->desc('post');
        $coro->{task} = $task;
        $coro->on_destroy($cb_wipe_post);

        my $status =
        with_coro_timeout {
            $engine->post($task, $self->{conf});
        } $coro, $self->{conf}{post_timeout};
        $coro->cancel($status, $task, $self);
    };
    cede;
}

#------------------------------------------------------------------------------------------------
#---------------------------------------  MAIN WIPE  --------------------------------------------
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
    $log->msg(1, "Starting wipe mode...");
    async {
        $queue->{get}->put({ proxy => $_ }) for (@{ $self->{proxies} });
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
    $log->msg(1, "Stopping wipe mode...");
    $_->cancel for (grep {$_->desc =~ /get|prepare|post|sleeping/ } Coro::State::list);
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
    $self->{is_running}   = 1;
    $self->{start_time}   = time;
    $self->{failed_proxy} = {};
    $self->{stats}    = {error => 0, posted => 0, wrong_captcha => 0, total => 0, speed => ''};
    $queue->{get}     = Coro::Channel->new();
    $queue->{prepare} = Coro::Channel->new();
    $queue->{post}    = Coro::Channel->new();
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
                            my @get_coro      = grep { $_->desc eq 'get'     } Coro::State::list;
                            my @prepare_coro  = grep { $_->desc eq 'prepare' } Coro::State::list;
                            my @post_coro     = grep { $_->desc eq 'post'    } Coro::State::list;

                            for my $coro (@post_coro, @prepare_coro, @get_coro)
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

    #-- Speed measuring
    $watchers->{speed} =
        AnyEvent->timer(after => 5, interval => 5, cb =>
                        sub
                        {
                            my ($posted, $stime, $u) = ($self->{stats}{posted}, $self->{start_time}, $self->{conf}{speed});
                            my $d;
                            $d = 1    if $u eq 'second';
                            $d = 60   if $u eq 'minute';
                            $d = 3600 if $u eq 'hour';
                            $self->{stats}{speed} = sprintf "%.3f posts per %s", ($posted / ((time - $stime)/$d)), $u;
                        }
                       );

    #-- Get watcher
    $watchers->{get} =
        AnyEvent->timer(after => 0.5, interval => 2, cb =>
                        sub
                        {
                            my @get_coro      = grep { $_->desc eq 'get'     } Coro::State::list;
                            my $thrs_available = $self->{conf}{max_cap_thrs} - scalar @get_coro;
                            $self->wipe_get($queue->{get}->get)
                                while $queue->{get}->size && $thrs_available--;
                        }
                       );

    #-- Prepare watcher
    $watchers->{prepare} =
        AnyEvent->timer(after => 2, interval => 2, cb =>
                        sub
                        {
                            my @prepare_coro  = grep { $_->desc eq 'prepare' } Coro::State::list;
                            my $thrs_available = -1;
                            #-- Max post threads limit
                            if ($self->{conf}{max_prp_thrs})
                            {
                                my $n = $self->{conf}{max_prp_thrs} - scalar @prepare_coro;
                                $thrs_available = $n > 0 ? $n : 0;
                            }

                            $self->wipe_prepare($queue->{prepare}->get)
                                while $queue->{prepare}->size && $thrs_available--;
                        }
                       );

    #-- Post watcher
    $watchers->{post} =
        AnyEvent->timer(after => 2, interval => 1, cb =>
                        sub
                        {
                            my @get_coro      = grep { $_->desc eq 'get'     } Coro::State::list;
                            my @prepare_coro  = grep { $_->desc eq 'prepare' } Coro::State::list;
                            my @post_coro     = grep { $_->desc eq 'post'    } Coro::State::list;

                            my $thrs_available = -1;
                            #-- Max post threads limit
                            if ($self->{conf}{max_pst_thrs})
                            {
                                my $n = $self->{conf}{max_pst_thrs} - scalar @post_coro;
                                $thrs_available = $n > 0 ? $n : 0;
                            }
                            if ($self->{conf}{salvo})
                            {
                                if (
                                    !@get_coro     && $queue->{get}->size     == 0 && 
                                    !@prepare_coro && $queue->{prepare}->size == 0 &&
                                    !@post_coro    && $queue->{post}->size
                                   )
                                {
                                    $log->msg(1, "#~~~ ". scalar($queue->{post}->size) ." charges are ready. Strike! ~~~#");
                                    $self->wipe_post($queue->{post}->get)
                                        while $queue->{post}->size && $thrs_available--;
                                }
                            }
                            elsif ($self->{conf}{salvoX})
                            {
                                if (!@post_coro && $queue->{post}->size >= $self->{conf}{max_pst_thrs})
                                {
                                    $log->msg(1, "#~~~ ". scalar($queue->{post}->size) ." charges are ready. Strike! ~~~#");
                                    $self->wipe_post($queue->{post}->get)
                                        while $queue->{post}->size && $thrs_available--;
                                }
                            }
                            else
                            {
                                $self->wipe_post($queue->{post}->get)
                                    while $queue->{post}->size && $thrs_available--;
                            }
                        }
                       );

    #-- post limit
    $watchers->{post_limit} =
        AnyEvent->timer(after => 5, interval => 5, cb => sub
                        {
                            if ($self->{stats}{posted} >= $self->{conf}{post_limit})
                            {
                                $self->stop;
                            }
                        },
                       ) if $self->{conf}{post_limit};
    #-- Exit watchers
    #-- BUG: Если ставить слишком малый interval, при одной прокси будет выходить когда не надо
    $watchers->{exit} =
        AnyEvent->timer(after => 5, interval => 5, cb =>
                        sub
                        {
                            my @get_coro      = grep { $_->desc eq 'get'     } Coro::State::list;
                            my @prepare_coro  = grep { $_->desc eq 'prepare' } Coro::State::list;
                            my @post_coro     = grep { $_->desc eq 'post'    } Coro::State::list;
                            my @sleep_coro    = grep { $_->desc eq 'sleeping'} Coro::State::list;

                            if (!(scalar @get_coro)      &&
                                !(scalar @post_coro)     &&
                                !(scalar @prepare_coro)  &&
                                !(scalar @sleep_coro)    &&
                                !($queue->{get}->size)   &&
                                !($queue->{post}->size)  &&
                                !($queue->{prepare}->size))
                            {
                                $self->stop;
                            }
                        }
                       ) if $self->{conf}{autoexit};
}
1;
