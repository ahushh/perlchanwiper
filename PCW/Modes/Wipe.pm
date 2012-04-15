package PCW::Modes::Wipe;

use strict;
use autodie;
use Carp;
use feature qw(switch say);

#------------------------------------------------------------------------------------------------
# Importing Coro packages
#------------------------------------------------------------------------------------------------
use AnyEvent;
use Coro::State;
use Coro::LWP;
use Coro::Timer;
use Coro;
# use EV;
use Time::HiRes;
#------------------------------------------------------------------------------------------------
# Importing utility packages
#------------------------------------------------------------------------------------------------
use File::Basename;
use File::Copy qw(move);
use File::Spec;
#------------------------------------------------------------------------------------------------
# Importing internal PCW packages
#------------------------------------------------------------------------------------------------
use PCW::Core::Log     qw(echo_msg echo_proxy);
use PCW::Core::Utils   qw(with_coro_timeout);
use PCW::Core::Captcha qw(captcha_report_bad);
use PCW::Modes::Common qw(get_posts_by_regexp);
#------------------------------------------------------------------------------------------------
# Package variables
#------------------------------------------------------------------------------------------------
our $CAPTCHA_DIR = 'captcha';
our $LOGLEVEL    = 0;
our $VERBOSE     = 0;
#------------------------------------------------------------------------------------------------
# Local variables
#------------------------------------------------------------------------------------------------
my $watchers  = {};
my $get_queue     ;
my $prepare_queue ;
my $post_queue    ;
#------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------
sub new($%)
{
    my ($class, %args) = @_;
    my $engine   = delete $args{engine};
    my $proxies  = delete $args{proxies};
    my $conf     = delete $args{conf};
    my $loglevel = delete $args{loglevel} || 1;
    my $verbose  = delete $args{verbose}  || 0;
    $LOGLEVEL = $loglevel;
    $VERBOSE  = $verbose;
    # TODO: check for errors in the chan-config file
    my @k = keys %args;
    Carp::croak("These options aren't defined: @k")
        if %args;

    my $self = {};
    $self->{engine}   = $engine;
    $self->{proxies}  = $proxies;
    $self->{conf}     = $conf;
    $self->{loglevel} = $loglevel;
    $self->{verbose}  = $verbose;
    bless $self, $class;
}

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
            $prepare_queue->put($task);
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
    async {
        my $coro = $Coro::current;
        $coro->desc('get');
        $coro->{task} = $task;
        $coro->on_destroy($cb_wipe_get);

        if ($task->{run_at})
        {
            my $now = Time::HiRes::time;
            echo_proxy(1, 'green', $task->{proxy}, 'GET', sprintf("sleep %d...", $self->{conf}{flood_limit}));
            echo_msg($LOGLEVEL >= 3, "sleep: ". int($task->{run_at} - $now) );
            Coro::Timer::sleep( int($task->{run_at} - $now) );
        }

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

    given ($msg)
    {
        when ('success')
        {
            $post_queue->put($task);
        }
        when ('no_captcha')
        {
            my $new_task = {proxy => $task->{proxy} };
            $get_queue->put($new_task);
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
            #-- Move successfully recognized captcha in the specified dir 
            if ($self->{conf}{save_captcha} && $task->{path_to_captcha})
            {
                my ($name, $path, $suffix) = fileparse($task->{path_to_captcha}, 'png', 'jpeg', 'jpg', 'gif');
                move $task->{path_to_captcha}, File::Spec->catfile($CAPTCHA_DIR, $task->{captcha_text} ."--". time .".$suffix");
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
        }
        when ('critical_error')
        {
            Carp::croak("Critical chan error. Going on is maybe purposelessly.");
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

    if ($self->{conf}{loop} && $msg ne 'banned' && $self->{failed_proxy}{ $task->{proxy} } < $self->{conf}{proxy_attempts})
    {
        echo_msg($LOGLEVEL >= 3, "push in the get queue: $task->{proxy}");
        $new_task->{proxy} = $task->{proxy};
        $get_queue->put($new_task);
    }
};

sub wipe_post($$$)
{
    my ($self, $task) = @_;
    my $engine = $self->{engine};
    async
    {
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
sub start($)
{
    my $self = shift;
    async {
        $self->_pre_init();
        #-- Initialization
        if ($self->{conf}{random_reply})
        {
            $PCW::Modes::Common::VERBOSE  = $VERBOSE;
            $PCW::Modes::Common::LOGLEVEL = $LOGLEVEL;
            my @posts = get_posts_by_regexp("http://no_proxy", $self->{engine}, $self->{conf}{random_reply});
            if (@posts)
            {
                $get_queue->put({ proxy => $_ }) for (@{ $self->{proxies} });
                $self->{conf}{post_cnf}{thread} = \@posts;
            }
        }
        else
        {
            $get_queue->put({ proxy => $_ }) for (@{ $self->{conf}{proxies} });
        }
        $self->_init_watchers();
        while ($self->{is_running})
        {
            Coro::Timer::sleep 1;
        }
    };
    cede;
}

sub _pre_init($)
{
    my $self = shift;
    $self->{is_running}   = 1;
    $self->{failed_proxy} = {};
    $self->{stats} = {error => 0, posted => 0, wrong_captcha => 0, total => 0};
    $get_queue     = Coro::Channel->new();
    $prepare_queue = Coro::Channel->new();
    $post_queue    = Coro::Channel->new();
}

sub _init_watchers($)
{
    my $self = shift;
    #-- Timeout watcher
    $watchers->{timeout} =
        AnyEvent->timer(after => 0.5, interval => 1, cb =>
                        sub
                        {
                            my @get_coro      = grep { $_->desc eq 'get'     } Coro::State::list;
                            my @prepare_coro  = grep { $_->desc eq 'prepare' } Coro::State::list;
                            my @post_coro     = grep { $_->desc eq 'post'    } Coro::State::list;

                            echo_msg($LOGLEVEL >= 3, sprintf "run: %d captcha, %d post, %d prepare coros.",
                                     scalar @get_coro, scalar @post_coro, scalar @prepare_coro);
                            echo_msg($LOGLEVEL >= 3, sprintf "queue: %d captcha, %d post, %d prepare coros.",
                                     $get_queue->size, $post_queue->size, $prepare_queue->size);

                            for my $coro (@post_coro, @prepare_coro, @get_coro)
                            {
                                my $now = Time::HiRes::time;
                                if ($coro->{timeout_at} && $now > $coro->{timeout_at})
                                {
                                    echo_proxy(1, 'red', $coro->{task}{proxy}, uc($coro->{desc}), '[TIMEOUT]');
                                    $coro->cancel('timeout', $coro->{task}, $self);
                                }
                            }
                        }
                       );

    #-- Find threads watcher
    $watchers->{threads} =
        AnyEvent->timer(after    => $self->{conf}{random_reply}{interval},
                        interval => $self->{conf}{random_reply}{interval},
                        cb       =>
                        sub
                        {
                            #-- Refresh the thread list
                            async {
                                my @posts = get_posts_by_regexp("http://no_proxy", $self->{engine}, $self->{conf}{random_reply});
                                $self->{conf}{post_cnf}{thread} = \@posts;
                            };
                            cede;
                        }
                       ) if $self->{conf}{random_reply};

    #-- Get watcher
    $watchers->{get} =
        AnyEvent->timer(after => 0.5, interval => 2, cb =>
                        sub
                        {
                            my @get_coro      = grep { $_->desc eq 'get'     } Coro::State::list;
                            my $thrs_available = $self->{conf}{max_cap_thrs} - scalar @get_coro;
                            $self->wipe_get($get_queue->get)
                                while $get_queue->size && $thrs_available--;
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

                            $self->wipe_prepare($prepare_queue->get)
                                while $prepare_queue->size && $thrs_available--;
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
                                    !@get_coro     && $get_queue->size     == 0 && 
                                    !@prepare_coro && $prepare_queue->size == 0 &&
                                    !@post_coro    && $post_queue->size
                                   )
                                {
                                    echo_msg(1, "#~~~ Start posting. ~~~#");
                                    $self->wipe_post($post_queue->get)
                                        while $post_queue->size && $thrs_available--;
                                }
                            }
                            else
                            {
                                $self->wipe_post($post_queue->get)
                                    while $post_queue->size && $thrs_available--;
                            }
                        }
                       );

    #-- Exit watchers
    #-- Если ставить слишком малый interval, при одной прокси будет выходить когда не надо
    $watchers->{exit} =
        AnyEvent->timer(after => 5, interval => 5, cb =>
                        sub
                        {
                            my @get_coro      = grep { $_->desc eq 'get'     } Coro::State::list;
                            my @prepare_coro  = grep { $_->desc eq 'prepare' } Coro::State::list;
                            my @post_coro     = grep { $_->desc eq 'post'    } Coro::State::list;
                            if (!(scalar @get_coro)      &&
                                !(scalar @post_coro)     &&
                                !(scalar @prepare_coro)  &&
                                !($get_queue->size)      &&
                                !($post_queue->size)     &&
                                !($prepare_queue->size)  or
                                #-- post limit was reached
                                ( $self->{conf}{post_limit} ? ($self->{stats}{posted} >= $self->{conf}{post_limit}) : undef ))
                            {
                                $self->stop;
                            }
                        }
                       );
}

sub stop($)
{
    my $self = shift;
    $self->{is_running} = 0;
}

1;
