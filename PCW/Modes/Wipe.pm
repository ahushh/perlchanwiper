package PCW::Modes::Wipe;

use v5.12;
use Moo;
use utf8;
use autodie;
use Hash::Util "lock_keys";

extends 'PCW::Modes::Base';

has 'start_time' => (
    is => 'rw',
);

has 'failed_proxy' => (
    is => 'rw',
);

has 'stats' => (
    is => 'rw',
);

has 'get_captcha_callback' => (
    is => 'rw',
);

has 'prepare_data_callback' => (
    is => 'rw',
);

has 'handle_captcha_callback' => (
    is => 'rw',
);

has 'make_post_callback' => (
    is => 'rw',
);

with 'PCW::Roles::Modes::Posting';

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
use PCW::Core::Utils qw/with_coro_timeout/;
#------------------------------------------------------------------------------------------------
my $go_to_bed_callback = unblock_sub
{
    my ($msg, $task, $self) = @_;
    $self->coro_queue->{get_captcha}->put({ proxy => $task->{proxy} });
};

my $get_captcha_callback = unblock_sub
{
    my ($msg, $task, $self) = @_;
    return unless @_;
    given ($msg)
    {
        when ('success')
        {
            $self->failed_proxy->{ $task->{proxy} } = 0;
            $self->coro_queue->{handle_captcha}->put($task);
        }
        when ('banned')
        {
            $self->failed_proxy->{ $task->{proxy} }++;
        }
        default
        {
            $self->failed_proxy->{ $task->{proxy} }++;
            my $errors = $self->failed_proxy->{ $task->{proxy} } || 0;
            my $limit  = $self->mode_config->{attempts}{get_captcha};
            if ($errors < $limit)
            {
                $self->log->pretty_proxy('GET_CAPTCHA_CB', 'red', $task->{proxy}, 'GET CB', "$msg: do get_captcha again ($errors/$limit)");
                $self->coro_queue->{get_captcha}->put({ proxy => $task->{proxy} });
            }
            else
            {
                $self->log->pretty_proxy('GET_CAPTCHA_CB', 'red', $task->{proxy}, 'GET CB', "$msg: reached the error limit ($errors/$limit)");
            }
        }
    }
};

my $prepare_data_callback = unblock_sub
{
    my ($msg, $task, $self) = @_;
    $self->coro_queue->{make_post}->put($task);
};

my $handle_captcha_callback = unblock_sub
{
    my ($msg, $task, $self) = @_;
    given ($msg)
    {
        when ('timeout')
        {
            $self->engine->ocr->report_bad($task->{path_to_captcha});
        }
        when ('success')
        {
            $self->coro_queue->{prepare_data}->put($task);
        }
        when ('no_text')
        {
            $self->engine->ocr->report_bad($task->{path_to_captcha});
            $self->coro_queue->{get_captcha}->put({ proxy => $task->{proxy} });
        }
        when ('error')
        {
            if ($self->mode_config->{wrong_captcha_retry} || $self->mode_config->{loop})
            {
                my $errors = $self->failed_proxy->{ $task->{proxy} } || 0;
                my $limit  = $self->mode_config->{attempts}{prepare_data};
                if ($errors < $limit)
                {
                    $self->log->pretty_proxy('PREPARE_DATA_CB', 'red', $task->{proxy}, 'PREPARE CB', "$msg: do handle_captcha again ($errors/$limit)");
                    $self->coro_queue->{get_captcha}->put({ proxy => $task->{proxy} });
                }
                else
                {
                   $self->log->pretty_proxy('PREPARE_DATA_CB', 'red', $task->{proxy}, 'PREPARE CB',
                                            "$msg: reached the error limit ($errors/$limit)");
                }
            }
        }
    }
};

my $make_post_callback = unblock_sub
{
    my ($msg, $task, $self) = @_;
    return unless @_;
    my $now = Time::HiRes::time;
    $self->stats->{total_sent}++;
    given ($msg)
    {
        when ('success')
        {
            #-- Update stats
            $self->stats->{posted}++;
            $self->stats->{OCR_accuracy} = sprintf("%d%", 100 * $self->stats->{posted} / ($self->stats->{wrong_captcha} + $self->stats->{posted}))
                if ($self->stats->{wrong_captcha} + $self->stats->{posted});

            #-- Move successfully recognized captcha into the specified dir
            if ($self->mode_config->{save_captcha} && $task->{path_to_captcha})
            {
                my ($name, $path, $suffix) = fileparse($task->{path_to_captcha}, 'png', 'jpeg', 'jpg', 'gif');
                my $dest = File::Spec->catfile($self->mode_config->{save_captcha}, $task->{captcha_text} ."--". time .".$suffix");
                move $task->{path_to_captcha}, $dest;
                $self->log->msg('MAKE_POST_CB', "moved $task->{path_to_captcha} to $dest");
            }
            #-- Sleep
            if ($self->mode_config->{loop})
            {
                my $time;
                if ($task->{content}{ $self->engine->chan_config->{fields}{post}{_thread} })
                {
                    $time = $self->engine->chan_config->{reply_delay};
                }
                else
                {
                    $time = $self->engine->chan_config->{new_thread_delay};
                }
                $self->coro_queue->{sleep}->put({ proxy => $task->{proxy}, run_at => $now+$time, time => $time });
            }
        }
        when ('wrong_captcha')
        {
            $self->engine->ocr->report_bad($task->{path_to_captcha});
            $self->stats->{wrong_captcha}++;
            $self->stats->{OCR_accuracy} = sprintf("%d%", 100 * $self->stats->{posted} / ($self->stats->{wrong_captcha} + $self->stats->{posted}))
                if ($self->stats->{wrong_captcha} + $self->stats->{posted});

            if ($self->mode_config->{wrong_captcha_retry} || $self->mode_config->{loop})
            {
                $self->log->pretty_proxy('MAKE_POST_CB', 'yellow', $task->{proxy}, 'POST CB', "$msg: request captcha again");
                $self->coro_queue->{get_captcha}->put({ proxy => $task->{proxy} });
            }
        }
        when ('too_fast')
        {
            #-- Sleep
            if ($self->mode_config->{loop})
            {
                my $time;
                if ($task->{content}{ $self->engine->chan_config->{fields}{post}{_thread} })
                {
                    $time = $self->engine->chan_config->{reply_delay};
                }
                else
                {
                    $time = $self->engine->chan_config->{new_thread_delay};
                }
                $self->coro_queue->{sleep}->put({ proxy => $task->{proxy}, run_at => $now+$time, time => $time });
            }
        }
        when ('same_message')
        {
        }
        when (/net_error|timeout|unknown/)
        {
            $self->stats->{error}++;
            $self->failed_proxy->{ $task->{proxy} }++;
            my $errors = $self->failed_proxy->{ $task->{proxy} } || 0;
            my $limit  = $self->mode_config->{attempts}{make_post};
            if ($errors < $limit)
            {
                $self->log->pretty_proxy('MAKE_POST_CB', 'red', $task->{proxy}, 'POST CB', "$msg: do make_post again ($errors/$limit)");
                $self->coro_queue->{make_post}->put($task);
                return;
            }
            else
            {
                $self->log->pretty_proxy('MAKE_POST_CB', 'red', $task->{proxy}, 'POST CB', "$msg: reached the error limit ($errors/$limit)");
            }
        }
        when ('banned')
        {
        }
        default
        {
            $self->log->pretty_proxy('MAKE_POST_CB', 'red', $task->{proxy}, 'POST CB', "$msg: something bad has occured");
        }
    }

    #-- Delete temporary files
    unlink($task->{path_to_captcha})
        if $task->{path_to_captcha} && -e $task->{path_to_captcha};
    unlink($task->{file_path})
        if $self->engine->common_config->{image}{altering} && $task->{file_path} && -e $task->{file_path};
};

sub BUILDARGS
{
    my ($class, @args) = @_;
    return {
            @args,
            get_captcha_callback    => $get_captcha_callback,
            prepare_data_callback   => $prepare_data_callback,
            handle_captcha_callback => $handle_captcha_callback,
            make_post_callback      => $make_post_callback,
            go_to_bed_callback      => $go_to_bed_callback,
           };
}

#------------------------------------------------------------------------------------------------
#---------------------------------------  MAIN WIPE  --------------------------------------------
#------------------------------------------------------------------------------------------------
sub start
{
    my $self = shift;
    return unless $self->is_running;
    $self->log->msg('MODE_STATE', "Starting wipe mode...");
    async {
        $Coro::current->desc('loop');
        $self->coro_queue->{get_captcha}->put({ proxy => $_ }) for (@{ $self->proxies });
        while ($self->is_running)
        {
            Coro::Timer::sleep 1;
        }
    };
    cede;
}

sub _base_init
{
    my $self = shift;
    $self->is_running(1);
    $self->start_time(time);
    $self->failed_proxy({});
    $self->stats({error => 0, posted => 0, wrong_captcha => 0, total_sent => 0, speed => 0, OCR_accuracy => 0 });
    for ((qw/sleep get_captcha prepare_data handle_captcha make_post/))
    {
        $self->coro_queue->{$_} = Coro::Channel->new();
    }
}

sub _init_base_watchers
{
    my $self = shift;
    #-- Coros watcher
    $self->watchers->{coros} =
        AnyEvent->timer(after => 0, interval => 5, cb =>
                        sub
                        {
                            my @sleep_coros          = grep { $_->desc eq 'sleep'     } Coro::State::list;
                            my @get_captcha_coros    = grep { $_->desc eq 'get_captcha'     } Coro::State::list;
                            my @prepare_data_coros   = grep { $_->desc eq 'prepare_data' } Coro::State::list;
                            my @make_post_coros      = grep { $_->desc eq 'make_post'    } Coro::State::list;
                            my @handle_captcha_coros = grep { $_->desc eq 'handle_captcha'} Coro::State::list;

                            $self->log->msg('ERROR', sprintf "run: %d sleep, %d get captcha, %d handle captcha, %d make post, %d prepare data coros.",
                                            scalar @sleep_coros,
                                            scalar @get_captcha_coros,
                                            scalar @handle_captcha_coros,
                                            scalar @make_post_coros,
                                            scalar @prepare_data_coros);
                            $self->log->msg('ERROR', sprintf "queue: %d sleep, %d get captcha, %d handle captcha, %d make post, %d prepare data coros.",
                                            $self->coro_queue->{sleep}->size,
                                            $self->coro_queue->{get_captcha}->size,
                                            $self->coro_queue->{handle_captcha}->size,
                                            $self->coro_queue->{make_post}->size,
                                            $self->coro_queue->{prepare_data}->size);
                        }
                       );

    #-- Timeout watcher
    $self->watchers->{timeout} =
        AnyEvent->timer(after => 0, interval => 1, cb =>
                        sub
                        {
                            for my $coro (Coro::State::list)
                            {
                                my $now = Time::HiRes::time;
                                if ($coro->{timeout_at} && $now > $coro->{timeout_at})
                                {
                                   $self->log->pretty_proxy('MODE_TIMEOUT', 'red', $coro->{task}{proxy}, uc($coro->{desc}), '[TIMEOUT]');
                                   $coro->cancel('timeout', $coro->{task}, $self);
                                }
                            }
                        }
                       );
    #-- Sleep watcher
    $self->watchers->{sleep} =
        AnyEvent->timer(after => 0.5, interval => 1, cb =>
                        sub
                        {
                            $self->go_to_bed($self->coro_queue->{sleep}->get)
                                while $self->coro_queue->{sleep}->size;
                        }
                       );


    #-- Get captcha watcher
    $self->watchers->{get_captcha} =
        AnyEvent->timer(after => 0.5, interval => 2, cb =>
                        sub
                        {
                            my @get_captcha_coros = grep { $_->desc eq 'get_captcha' } Coro::State::list;
                            my $thrs_available = $self->mode_config->{max_threads}{get_captcha} - scalar @get_captcha_coros;
                            $thrs_available    = 0 if $thrs_available < 0;
                            $self->get_captcha($self->coro_queue->{get_captcha}->get)
                                while $self->coro_queue->{get_captcha}->size && $thrs_available--;
                        }
                       );

    #-- Prepare data watcher
    $self->watchers->{prepare_data} =
        AnyEvent->timer(after => 2, interval => 2, cb =>
                        sub
                        {
                            my @prepare_data_coros = grep { $_->desc eq 'prepare_data' } Coro::State::list;
                            my $thrs_available = $self->mode_config->{max_threads}{prepare_data} - scalar @prepare_data_coros;
                            $thrs_available    = 0 if $thrs_available < 0;
                            $self->prepare_data($self->coro_queue->{prepare_data}->get)
                                while $self->coro_queue->{prepare_data}->size && $thrs_available--;
                        }
                       );

    #-- Handle captcha watcher
    $self->watchers->{handle_captcha} =
        AnyEvent->timer(after => 2, interval => 2, cb =>
                        sub
                        {
                            my @handle_captcha_coros = grep { $_->desc eq 'handle_captcha' } Coro::State::list;
                            my $thrs_available = $self->mode_config->{max_threads}{handle_captcha} - scalar @handle_captcha_coros;
                            $thrs_available    = 0 if $thrs_available < 0;
                            $self->handle_captcha($self->coro_queue->{handle_captcha}->get)
                                while $self->coro_queue->{handle_captcha}->size && $thrs_available--;
                        }
                       );

    #-- Make post watcher
    $self->watchers->{make_post} =
        AnyEvent->timer(after => 2, interval => 1, cb =>
                        sub
                        {
                            my @make_post_coros = grep { $_->desc eq 'make_post' } Coro::State::list;
                            my $thrs_available = $self->mode_config->{max_threads}{make_post} - scalar @make_post_coros;
                            $thrs_available    = 0 if $thrs_available < 0;
                            given ($self->mode_config->{send}{mode})
                            {
                                when ('accumulate')
                                {
                                    if (scalar $self->coro_queue->{make_post}->size >= $self->mode_config->{send}{accumulate}{number})
                                    {
                                        $self->log->msg('WIPE_STRIKE', "#~~~ ".
                                                                       scalar($self->coro_queue->{make_post}->size).
                                                                       " ready rounds. FIRE FIRE FIRE!!! ~~~#", '', 'red');
                                        $self->make_post($self->coro_queue->{make_post}->get)
                                            while $self->coro_queue->{make_post}->size && $thrs_available--;
                                    }
                                }
                                default
                                {
                                    $self->make_post($self->coro_queue->{make_post}->get)
                                        while $self->coro_queue->{make_post}->size && $thrs_available--;
                                }
                            }
                        }
                       );
}
1;
