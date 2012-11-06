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
    my $log = $self->{log};

    given ($msg)
    {
        when ('success')
        {
            $self->{failed_proxy}{ $task->{proxy} } = 0;
            $log->pretty_proxy('MODE_CB', 'green', $task->{proxy}, 'GET CB', "$msg: push into the PREPARE queue");
            $queue->{prepare}->put($task);
        }
        default
        {
            $self->{failed_proxy}{ $task->{proxy} }++;
            if ($self->{failed_proxy}{ $task->{proxy} } < $self->{conf}{get_attempts})
            {
                my $new_task = {proxy => $task->{proxy} };
                $log->pretty_proxy('MODE_CB', 'red', $task->{proxy}, 'GET CB', "$msg: push into the GET queue");
                $queue->{get}->put($new_task);
            }
            else
            {
                $log->pretty_proxy('MODE_CB', 'red', $task->{proxy}, 'GET CB', "$msg: reached the error limit; threw away the proxy");
            }
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
            $log->pretty_proxy('MODE_SLEEP', 'green', $task->{proxy}, 'GET',
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
            $log->pretty_proxy('MODE_CB', 'green', $task->{proxy}, 'PREPARE CB', "$msg: push into the POST queue");
            $self->{failed_proxy}{ $task->{proxy} } = 0;
        }
        when ('no_text')
        {
            captcha_report_bad($self->{log}, $self->{conf}{captcha_decode}, $task->{path_to_captcha});
        }
        when (/no_text|error/)
        {
            $self->{failed_proxy}{ $task->{proxy} }++;
            if ($self->{conf}{wcap_retry} || $self->{conf}{loop})
            {
                if ($self->{failed_proxy}{ $task->{proxy} } < $self->{conf}{prepare_attempts})
                {
                    my $new_task = {proxy => $task->{proxy} };
                    $log->pretty_proxy('MODE_CB', 'red', $task->{proxy}, 'PREPARE CB', "$msg: push into the GET queue");
                    $queue->{get}->put($new_task);
                }
                else
                {
                    $log->pretty_proxy('MODE_CB', 'red', $task->{proxy}, 'PREPARE CB', "$msg: reached the error limit; threw away the proxy");
                }
            }
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
            $self->{stats}{OCR_accuracy} = sprintf("%d%", 100 * $self->{stats}{posted} / ($self->{stats}{wrong_captcha} + $self->{stats}{posted}))
                if ($self->{stats}{wrong_captcha} + $self->{stats}{posted});
            #-- Move successfully recognized captcha into the specified dir
            if ($self->{conf}{save_captcha} && $task->{path_to_captcha})
            {
                my ($name, $path, $suffix) = fileparse($task->{path_to_captcha}, 'png', 'jpeg', 'jpg', 'gif');
                my $dest = File::Spec->catfile($self->{conf}{save_captcha}, $task->{captcha_text} ."--". time .".$suffix");
                move $task->{path_to_captcha}, $dest;
                $log->msg('MODE_CB', "move $task->{path_to_captcha} to $dest");
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
            $self->{stats}{OCR_accuracy} = sprintf("%d%", 100 * $self->{stats}{posted} / ($self->{stats}{wrong_captcha} + $self->{stats}{posted}))
                if ($self->{stats}{wrong_captcha} + $self->{stats}{posted});
            captcha_report_bad($self->{log}, $self->{conf}{captcha_decode}, $task->{path_to_captcha});
            if ($self->{conf}{wcap_retry})
            {
                $log->pretty_proxy('MODE_CB', 'yellow', $task->{proxy}, 'POST CB', "$msg: push into the GET queue");
                $new_task->{proxy} = $task->{proxy};
                $queue->{get}->put($new_task);
                return;
            }
        }
        when ('critical_error')
        {
            $log->msg("ERROR", "WTF?! A critical chan error has occured!", '', 'red');
            $log->pretty_proxy('MODE_CB', 'red', $task->{proxy}, 'POST CB', "$msg: push into the POST queue");
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

    if ($self->{conf}{loop} && $msg ne 'banned')
    {
        if ($self->{failed_proxy}{ $task->{proxy} } < $self->{conf}{post_attempts})
        {
            $log->pretty_proxy('MODE_CB', 'red', $task->{proxy}, 'POST CB', "$msg: push into the GET queue");
            $new_task->{proxy} = $task->{proxy};
            $queue->{get}->put($new_task);
        }
        else
        {
            $log->pretty_proxy('MODE_CB', 'red', $task->{proxy}, 'POST CB', "$msg: reached the error limit; threw away the proxy");
        }

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
# Web UI
#------------------------------------------------------------------------------------------------
sub send_posts($)
{
    my $self  = shift;
    my $log  = $self->{log};
    my @post_coro = grep { $_->desc eq 'post'    } Coro::State::list;
    my $thrs_available = -1;
    if ($self->{conf}{max_pst_thrs})
    {
        my $n = $self->{conf}{max_pst_thrs} - scalar @post_coro;
        $thrs_available = $n > 0 ? $n : 0;
    }
    $log->msg('WIPE_STRIKE', "#~~~ ". scalar($queue->{post}->size) ." ready rounds. Strike! ~~~#");
    $self->wipe_post($queue->{post}->get)
        while $queue->{post}->size && $thrs_available--;
}
#------------------------------------------------------------------------------------------------
#---------------------------------------  MAIN WIPE  --------------------------------------------
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
    $log->msg('MODE_STATE', "Starting wipe mode...");
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
    $log->msg('MODE_STATE', "Stopping wipe mode...");
    $_->cancel for (grep {$_->desc =~ /custom-watcher|get|prepare|post|sleeping/ } Coro::State::list);
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
    $self->{stats}    = {error => 0, posted => 0, wrong_captcha => 0, total => 0, speed => '', OCR_accuracy => '' };
    $queue->{get}     = Coro::Channel->new();
    $queue->{prepare} = Coro::Channel->new();
    $queue->{post}    = Coro::Channel->new();
}

sub _init_base_watchers($)
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
                                    $log->pretty_proxy('MODE_TIMEOUT', 'red', $coro->{task}{proxy}, uc($coro->{desc}), '[TIMEOUT]');
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
                            my @post_coro     = grep { $_->desc eq 'post'    } Coro::State::list;
                            #-- Масс постинг включен и во время него капчу скачивать не надо
                            if ($self->{conf}{send}{mode} > 0 and @post_coro and
                                $self->{conf}{send}{wait_for_all} == 2)
                            {
                                return;
                            }
                            my @get_coro       = grep { $_->desc eq 'get'     } Coro::State::list;
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
                            my @post_coro     = grep { $_->desc eq 'post'    } Coro::State::list;
                            if ($self->{conf}{send}{mode} > 0 and @post_coro and
                                $self->{conf}{send}{wait_for_all} >= 1)
                            {
                                return;
                            }
                            my @prepare_coro   = grep { $_->desc eq 'prepare' } Coro::State::list;
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
                            if ($self->{conf}{send}{mode} == 1 or $self->{conf}{send}{mode} == 3)
                            {
                                if (
                                    !@get_coro     && $queue->{get}->size     == 0 &&
                                    !@prepare_coro && $queue->{prepare}->size == 0 &&
                                    !@post_coro    && $queue->{post}->size
                                   )
                                {
                                    $log->msg('WIPE_STRIKE', "#~~~ ". scalar($queue->{post}->size) ." ready rounds. Strike! ~~~#");
                                    $self->wipe_post($queue->{post}->get)
                                        while $queue->{post}->size && $thrs_available--;
                                    $self->{conf}{send}{mode} = 0 if $self->{conf}{send}{mode} == 3;
                                }
                            }
                            elsif ($self->{conf}{send}{mode} == 2 or $self->{conf}{send}{mode} == 4)
                            {
                                if (!@post_coro && $queue->{post}->size >= $self->{conf}{send}{caps_accum})
                                {
                                    $log->msg('WIPE_STRIKE', "#~~~ ". scalar($queue->{post}->size) ." ready rounds. Strike! ~~~#");
                                    $self->wipe_post($queue->{post}->get)
                                        while $queue->{post}->size && $thrs_available--;
                                    $self->{conf}{send}{mode} = 0 if $self->{conf}{send}{mode} == 4;
                                }
                            }
                            elsif ($self->{conf}{send}{mode} == 5)
                            {
                                #-- ничего не делаем - ждем ручного подтверждения
                                undef;
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
