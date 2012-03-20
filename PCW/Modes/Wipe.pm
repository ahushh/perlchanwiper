package PCW::Modes::Wipe;

use strict;
use autodie;
use Carp;

#use Exporter 'import';
#our @EXPORT_OK = qw(wipe);
#------------------------------------------------------------------------------------------------
# Package Variables
#------------------------------------------------------------------------------------------------
our $CAPTCHA_DIR = 'captcha';
our $LOGLEVEL   = 0;
our $VERBOSE = 0;
 
#------------------------------------------------------------------------------------------------
# Importing Coro packages
#------------------------------------------------------------------------------------------------
use AnyEvent;
use Coro::State;
use Coro::LWP;
use Coro::Timer;
use Coro;
use EV;
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
 
#------------------------------------------------------------------------------------------------
# Local package variables and procedures
#------------------------------------------------------------------------------------------------
my $get_queue     = Coro::Channel->new();
my $prepare_queue = Coro::Channel->new();
my $post_queue    = Coro::Channel->new();
my %failed_proxy  = ();
my %stats         = (error => 0, posted => 0, wrong_captcha => 0, total => 0);

sub show_stats
{
    my @good = grep { $failed_proxy{$_} == 0 } keys %failed_proxy;
    print "\nSuccessfully posted: $stats{posted}\n";
    print "Wrong captcha: $stats{wrong_captcha}\n";
    print "Other failed: $stats{error}\n";
    print "Total posted: $stats{total}\n";
    print "Good proxies: ", scalar @good, "\n";
};

#------------------------------------------------------------------------------------------------
#-----------------------------------------  WIPE GET --------------------------------------------
#------------------------------------------------------------------------------------------------
#-- Coro callback
my $cb_wipe_get = sub
{ 
    my ($msg, $task, $cnf) = @_;
    return unless @_;

    if ($msg eq 'success')
    {
        $prepare_queue->put($task);
    }
    elsif ($msg =~ /net_error|timeout/)
    {
        $failed_proxy{ $task->{proxy} }++;
    }
    else
    {
        #-- WTF?! TODO: to find out
        $failed_proxy{ $task->{proxy} } = 0;
    }
};

sub wipe_get($$$)
{
    my ($engine, $task, $cnf) = @_;
    async {
        my $coro = $Coro::current;
        $coro->desc('get');
        $coro->{proxy} = $task->{proxy}; #-- Для вывода timeout
        $coro->on_destroy($cb_wipe_get);

        if ($task->{run_at})
        {
            my $now = Time::HiRes::time;
            echo_proxy(1, 'green', $task->{proxy}, 'GET', "sleep $cnf->{flood_limit}...");
            echo_msg($LOGLEVEL >= 3, "sleep: ". int($task->{run_at} - $now) );
            Coro::Timer::sleep( int($task->{run_at} - $now) );
        }

        my $status = 
        with_coro_timeout {
            $engine->get($task, $cnf);
        } $coro, $cnf->{get_timeout};
        $coro->cancel($status, $task, $cnf);
    };
    cede;
}

#------------------------------------------------------------------------------------------------
#--------------------------------------  WIPE PREPARE -------------------------------------------
#------------------------------------------------------------------------------------------------
#-- Coro callback
my $cb_wipe_prepare = sub 
{
    my ($msg, $task, $cnf) = @_;
    return unless @_;

    if ($msg eq 'success')
    {
        $post_queue->put($task);
    }
    elsif ($msg eq 'no_captcha')
    {
        my $new_task = {proxy => $task->{proxy} };
        $get_queue->put($new_task);
    }
    elsif ($msg =~ /net_error|timeout/)
    {
        $failed_proxy{ $task->{proxy} }++;
    }
    else
    {
        $failed_proxy{ $task->{proxy} } = 0;
    }
};

sub wipe_prepare($$$)
{
    my ($engine, $task, $cnf) = @_;
    async {
        my $coro = $Coro::current;
        $coro->desc('prepare');
        $coro->{proxy} = $task->{proxy}; #-- Для вывода timeout
        $coro->on_destroy($cb_wipe_prepare);
        my $status =
        with_coro_timeout {
            $engine->prepare($task, $cnf);
        } $coro, $cnf->{prepare_timeout};
        $coro->cancel($status, $task, $cnf);
    };
    cede;
}

#------------------------------------------------------------------------------------------------
#----------------------------------------  WIPE POST  -------------------------------------------
#------------------------------------------------------------------------------------------------
#-- Coro callback
my $cb_wipe_post = sub 
{
    my ($msg, $task, $cnf) = @_;
    return unless @_;

    #-- Delete temporary files
    unlink($task->{path_to_captcha})
        if !$cnf->{save_captcha} && $task->{path_to_captcha} && -e $task->{path_to_captcha};
    unlink($task->{file_path})
        if $cnf->{img_data}{altering} && $task->{file_path} && -e $task->{file_path};

    $stats{total}++;
    my $new_task = {};
    if ($msg eq 'success') 
    {
        #-- Move successfully recognized captcha in the specified dir 
        if ($cnf->{save_captcha} && $task->{path_to_captcha})
        {
            my ($name, $path, $suffix) = fileparse($task->{path_to_captcha}, 'png', 'jpeg', 'jpg', 'gif');
            move $task->{path_to_captcha}, File::Spec->catfile($CAPTCHA_DIR, $task->{captcha_text} ."--". time .".$suffix");
        }
        $stats{posted}++;

        if ($cnf->{flood_limit} && $cnf->{loop})
        {
            my $now = Time::HiRes::time;
            $new_task->{run_at} = $now + $cnf->{flood_limit};
        }
    }
    elsif ($msg eq 'wrong_captcha')
    {
        $stats{wrong_captcha}++;
        captcha_report_bad($cnf->{captcha_decode}, $task->{path_to_captcha});
    }
    elsif ($msg eq 'critical_error')
    {
        Carp::croak("Critical chan error. Going on is purposelessly.");
    }
    elsif ($msg eq 'flood')
    {
        $stats{error}++;
        if ($cnf->{flood_limit} && $cnf->{loop})
        {
            my $now = Time::HiRes::time;
            $new_task->{run_at} = $now + $cnf->{flood_limit};
        }
    }
    else
    {
        $stats{error}++;
    }

    if ($msg =~ /net_error|timeout/)
    #if ($msg =~ /net_error|timeout|unknown/)
    {
        $failed_proxy{ $task->{proxy} }++;
    }
    else
    {
        $failed_proxy{ $task->{proxy} } = 0;
    }
    if ($cnf->{loop} && $msg ne 'banned' && $failed_proxy{ $task->{proxy} } < $cnf->{proxy_attempts})
    {
        echo_msg($LOGLEVEL >= 3, "push in the get queue: $task->{proxy}");
        $new_task->{proxy} = $task->{proxy};
        $get_queue->put($new_task);
    }
};

sub wipe_post($$$)
{
    my ($engine, $task, $cnf) = @_;
    async
    {
        my $coro = $Coro::current;
        $coro->desc('post');
        $coro->{proxy} = $task->{proxy}; #-- Для вывода timeout
        $coro->on_destroy($cb_wipe_post);

        my $status = 
        with_coro_timeout {
            $engine->post($task, $cnf);
        } $coro, $cnf->{post_timeout};
        $coro->cancel($status, $task, $cnf);
    };
    cede;
}

#------------------------------------------------------------------------------------------------
#---------------------------------------  MAIN WIPE  --------------------------------------------
#------------------------------------------------------------------------------------------------
sub get_threads($$$)
{
    my ($proxy, $engine, $cnf) = @_;
    my @threads;
    my $task = {proxy => $proxy };
    for my $page (@{ $cnf->{random_reply}{pages} })
    {
        my %local_post_cnf = %{ $cnf->{post_cnf} };
        $local_post_cnf{page} = $page;

        #-- Get the page
        echo_msg($LOGLEVEL >= 1, "Downloading $page page...");
        my ($html, undef, $status) = $engine->get_page($task, \%local_post_cnf);
        echo_msg($LOGLEVEL >= 1, "Page $page downloaded: $status");

        my %allthreads = $engine->get_all_threads($html);
        @threads = (@threads, keys(%allthreads));
    }
    return \@threads;
}

sub wipe($$%)
{
    my ($self, $engine, %cnf) =  @_;

    #-- Initialization
    if ($cnf{random_reply})
    {
        $cnf{post_cnf}{thread} = get_threads("http://no_proxy", $engine, \%cnf);
        my @ttr = @{ $cnf{post_cnf}{thread} };
        echo_msg(1, sprintf "%d threads were found", scalar @ttr);
    }
    $get_queue->put({ proxy => $_ }) for (@{ $cnf{proxies} });

    #-- Timeout watcher
    my $tw = AnyEvent->timer(after => 0.5, interval => 1, cb =>
        sub
        {
            my @get_coro      = grep { $_->desc eq 'get'     } Coro::State::list;
            my @prepare_coro  = grep { $_->desc eq 'prepare' } Coro::State::list;
            my @post_coro     = grep { $_->desc eq 'post'    } Coro::State::list;

            echo_msg($LOGLEVEL >= 2, sprintf "run: %d captcha, %d post, %d prepare coros.",
                scalar @get_coro, scalar @post_coro, scalar @prepare_coro);
            echo_msg($LOGLEVEL >= 2, sprintf "queue: %d captcha, %d post, %d prepare coros.",
                $get_queue->size, $post_queue->size, $prepare_queue->size);

            for my $coro (@post_coro, @get_coro)
            {
                my $now = Time::HiRes::time;
                if ($coro->{timeout_at} && $now > $coro->{timeout_at})
                {
                    echo_proxy(1, 'red', $coro->{proxy}, uc($coro->{desc}), '[TIMEOUT]');
                    $coro->cancel('timeout');
                }
            }
        }
    );

    #-- Find threads watcher
    my $ftw = AnyEvent->timer(after    => $cnf{random_reply}{interval},
                              interval => $cnf{random_reply}{interval},
                              cb =>
                              sub
                              {
                                  #-- Refresh the thread list
                                  async {
                                      $cnf{post_cnf}{thread} = get_threads("http://no_proxy", $engine, \%cnf);
                                  };
                                  cede;
                              }
                             ) if $cnf{random_reply};

    #-- Get watcher
    my $gw = AnyEvent->timer(after => 0.5, interval => 2, cb =>
        sub
        {
            my @get_coro      = grep { $_->desc eq 'get'     } Coro::State::list;
            my $thrs_available = $cnf{max_cap_thrs} - scalar @get_coro;
            wipe_get($engine, $get_queue->get, \%cnf)
                while $get_queue->size && $thrs_available--;
        }
    );

    #-- Prepare watcher
    my $prw = AnyEvent->timer(after => 2, interval => 2, cb =>
        sub
        {
            my @prepare_coro  = grep { $_->desc eq 'prepare' } Coro::State::list;
            my $thrs_available = -1;
            #-- Max post threads limit
            if ($cnf{max_prp_thrs})
            {
                my $n = $cnf{max_prp_thrs} - scalar @prepare_coro;
                $thrs_available = $n > 0 ? $n : 0;
            }

            wipe_prepare($engine, $prepare_queue->get, \%cnf)
                while $prepare_queue->size && $thrs_available--;
        }
    );

    #-- Post watcher
    my $pw = AnyEvent->timer(after => 2, interval => 1, cb =>
        sub
        {
            my @get_coro      = grep { $_->desc eq 'get'     } Coro::State::list;
            my @prepare_coro  = grep { $_->desc eq 'prepare' } Coro::State::list;
            my @post_coro     = grep { $_->desc eq 'post'    } Coro::State::list;

            my $thrs_available = -1;
            #-- Max post threads limit
            if ($cnf{max_pst_thrs})
            {
                my $n = $cnf{max_pst_thrs} - scalar @post_coro;
                $thrs_available = $n > 0 ? $n : 0;
            }
            if ($cnf{salvo})
            {
                if (
                    !@get_coro     && $get_queue->size     == 0 && 
                    !@prepare_coro && $prepare_queue->size == 0 &&
                    !@post_coro    && $post_queue->size
                   )
                {
                    echo_msg($LOGLEVEL >= 2, "#~~~ Start posting. ~~~#");
                    wipe_post($engine, $post_queue->get, \%cnf) 
                        while $post_queue->size && $thrs_available--;
                }
            }
            else
            {
                wipe_post($engine, $post_queue->get, \%cnf) 
                    while $post_queue->size && $thrs_available--;
            }
        }
    );

    #-- Exit watchers
    my $ew = AnyEvent->timer(after => 5, interval => 1, cb =>
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
                ( $cnf{post_limit} ? ($stats{posted} >= $cnf{post_limit}) : undef ))
            {
                EV::break;
                show_stats();
            }
        }
    );

    my $sw = AnyEvent->signal(signal => 'INT', cb =>
        sub
        {
            EV::break;
            show_stats();
            exit;
        }
    );

    EV::run;
}

1;
