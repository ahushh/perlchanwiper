package PCW::Modes::Delete;
 
use strict;
use autodie;
use Carp;

use Exporter 'import';
our @EXPORT_OK = qw(get_deletion_posts);
 
#------------------------------------------------------------------------------------------------
# Package Variables
#------------------------------------------------------------------------------------------------
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
# Importing internal PCW packages
#------------------------------------------------------------------------------------------------
use PCW::Core::Log   qw(echo_msg echo_proxy);
use PCW::Core::Net   qw(http_get);
use PCW::Core::Utils qw(with_coro_timeout);
 
#------------------------------------------------------------------------------------------------
# Local package variables and procedures
#------------------------------------------------------------------------------------------------
my $delete_queue = Coro::Channel->new();
my %stats  = (error => 0, deleted => 0, total => 0);
 
sub show_stats()
{
    print "\nSuccessfully deleted: $stats{deleted}\n";
    print "Error: $stats{error}\n";
    print "Total: $stats{total}\n";
};

#------------------------------------------------------------------------------------------------
#----------------------------------  DELETE POST  -----------------------------------------------
#------------------------------------------------------------------------------------------------
#-- Coro callback
my $cb_delete_post = sub
{
    my ($msg, $task, $cnf) = @_;
    $stats{total}++;
    if ($msg eq 'success')
    {
        $stats{deleted}++;
    }
    # TODO перезапуск при ошибке 
    else
    {
        $stats{error}++;
    }
};
 
sub delete_post($$$)
{
    my ($engine, $task, $cnf) = @_;
    async {
        my $coro = $Coro::current;
        $coro->desc('delete');
        $coro->{proxy} = $task->{proxy}; #-- Для вывода timeout
        $coro->on_destroy($cb_delete_post);
        my $status =
        with_coro_timeout {
            $engine->delete($task, $cnf);
        } $coro, $cnf->{delete_timeout};
        $coro->cancel($status, $task, $cnf);
    };
    cede;
}

#------------------------------------------------------------------------------------------------
#------------------------------------  MAIN DELETE  ---------------------------------------------
#------------------------------------------------------------------------------------------------
sub get_deletion_posts($$%)
{
    my ($proxy, $engine, %cnf) =  @_;
     
    my @deletion_posts;
    my $get_task = {
        proxy    => $proxy,
    };
     
    my %all_posts = ();
    #-- Search posts in the threads
    if ($cnf{delete_cnf}{thread})
    {
        for my $thread (@{ $cnf{delete_cnf}{thread} })
        {
            my %local_delete_cnf = %{ $cnf{delete_cnf} }; 
            $local_delete_cnf{thread} = $thread;
             
            #-- Get the thread
            echo_msg($LOGLEVEL >= 2, "Downloading $thread thread...");
            my ($html, undef, $status) = $engine->get_thread($get_task, \%local_delete_cnf);
            echo_msg($LOGLEVEL >= 2, "Thread $thread downloaded: $status");
             
            %all_posts = (%all_posts, $engine->get_all_replies($html));
        }
    }
    #use Data::Dumper; print Dumper(%all_posts); exit;
    #-- Search thread on the pages
    if ($cnf{delete_cnf}{page})
    {
        for my $page (@{ $cnf{delete_cnf}{page} })
        {
            my %local_delete_cnf = %{ $cnf{delete_cnf} }; 
            $local_delete_cnf{page} = $page;
             
            #-- Get the page
            echo_msg($LOGLEVEL >= 2, "Downloading $page page...");
            my ($html, undef, $status) = $engine->get_page($get_task, \%local_delete_cnf);
            echo_msg($LOGLEVEL >= 2, "Page $page downloaded: $status");
             
            %all_posts = (%all_posts, $engine->get_all_threads($html));
        }
    }
    unless ($cnf{delete_cnf}{page} || $cnf{delete_cnf}{thread})
    {
        Carp::croak("Options 'thread' or/and 'page' should be specified.");
    }
     
    echo_msg($LOGLEVEL >= 2, sprintf "%d posts and threads were found", scalar keys %all_posts);
     
    my $pattern = $cnf{delete_cnf}{find};
    for (keys %all_posts)
    {
        if ($all_posts{$_} =~ /$pattern/mg)
        {
            push @deletion_posts, $_;
        }
    }
    echo_msg($LOGLEVEL >= 2, sprintf "%d posts and threads matched the pattern", scalar @deletion_posts);
    return @deletion_posts;
}
 
sub delete($$$%)
{
    my ($self, $engine, %cnf) =  @_;
     
    my $proxy = shift @{ $cnf{proxies} };
    echo_msg($LOGLEVEL >= 2, "Used proxy: $proxy");
    #-------------------------------------------------------------------
    #-- Initialization
    #-------------------------------------------------------------------
    my @deletion_posts;
    if ($cnf{delete_cnf}{by_id})
    {
        @deletion_posts = @{ $cnf{delete_cnf}{by_id} };
    }
    elsif ($cnf{delete_cnf}{find})
    {
        @deletion_posts = get_deletion_posts($proxy, $engine, %cnf);
    }
    else
    {
        Carp::croak("Option 'by_id' or 'find' should be specified.");
    }
     
    for my $postid (@deletion_posts)
    {
        my $task = {
            proxy    => $proxy,
            board    => $cnf{delete_cnf}->{board},
            password => $cnf{delete_cnf}->{password},
            delete   => $postid,
        };
        $delete_queue->put($task); 
    }
    #-------------------------------------------------------------------
    #-------------------------------------------------------------------
     
    #-- Timeout watcher    
    my $tw = AnyEvent->timer(after => 0.5, interval => 1, cb =>
        sub
        {
            my @delete_coro  = grep { $_->desc eq 'delete' } Coro::State::list;
             
            echo_msg($LOGLEVEL >= 2, sprintf "run: %d; queue: %d", scalar @delete_coro, $delete_queue->size);
                       
            for my $coro (@delete_coro)
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
     
	#-- Delete watcher
    my $dw = AnyEvent->timer(after => 0.5, interval => 2, cb =>
        sub
        {
            my @delete_coro  = grep { $_->desc eq 'delete' } Coro::State::list;
            my $thrs_available = -1;
            #-- Max delete threads limit
            if ($cnf{max_del_thrs})
            {
                my $n = $cnf{max_del_thrs} - scalar @delete_coro;
                $thrs_available = $n > 0 ? $n : 0;
            }
             
            delete_post($engine, $delete_queue->get, \%cnf)
                while $delete_queue->size && $thrs_available--;
        }
    );
     
    #-- Exit watchers
    my $ew = AnyEvent->timer(after => 1, interval => 2, cb =>
        sub
        {
            my @delete_coro  = grep { $_->desc eq 'delete' } Coro::State::list;
            if (!@delete_coro && !$delete_queue->size)
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
