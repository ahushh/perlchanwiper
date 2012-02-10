package PCW::Modes::Delete;
 
use strict;
use autodie;
use Carp;

use Exporter 'import';
our @EXPORT_OK = qw(delete);
 
#------------------------------------------------------------------------------------------------
# Package Variables
#------------------------------------------------------------------------------------------------
our $DEBUG   = 0;
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
use PCW::Core::Log qw(echo_msg echo_msg_dbg echo_proxy echo_proxy_dbg);
use PCW::Core::Net qw(http_get);
use PCW::Utils     qw(with_coro_timeout);
 
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
    my ($msg, $task, $chan, $cnf) = @_;
    $stats{total}++;
    if ($msg eq 'success')
    {
        $stats{deleted}++;
    }
    else
    {
        $stats{error}++;
    }
};
 
sub delete_post($$$$)
{
    my ($engine, $task, $chan, $cnf) = @_;
    async {
        my $coro = $Coro::current;
        $coro->desc('delete');
        $coro->{proxy} = $task->{proxy}; #-- Для вывода timeout
        $coro->on_destroy($cb_delete_post);
        my $status =
        with_coro_timeout {
            $engine->delete($task, $chan, $cnf);
        } $coro, $cnf->{delete_timeout};
        $coro->cancel($status, $task, $chan, $cnf);
    };
    cede;
}

#------------------------------------------------------------------------------------------------
sub get_page($$$$)
{
    my ($engine, $task, $chan, $cnf) = @_;
    my $coro = async
    {
        my ($response, $response_headers, $status_line) = $engine->get_page($task, $chan, $cnf);
        return $response, $response_headers, $status_line;
    };
    $coro->{proxy} = $task->{proxy}; #-- Для вывода timeout
     
    return $coro->join;
}
 
sub get_thread($$$$)
{
    my ($engine, $task, $chan, $cnf) = @_;
    my $coro = async
    {
        my ($response, $response_headers, $status_line) = $engine->get_thread($task, $chan, $cnf);
        return $response, $response_headers, $status_line;
    };
    $coro->{proxy} = $task->{proxy}; #-- Для вывода timeout
    return $coro->join;
}
 
#------------------------------------------------------------------------------------------------
#------------------------------------  MAIN DELETE  ---------------------------------------------
#------------------------------------------------------------------------------------------------
sub delete($$%)
{
    my ($self, $engine, $chan, %cnf) =  @_;
     
    my $proxy = shift @{ $cnf{proxies} };
    #-------------------------------------------------------------------
    #-- Initialization
    #-------------------------------------------------------------------
    my @posts_for_del;
    if ($cnf{delete_cnf}{by_id})
    {
        @posts_for_del = @{ $cnf{delete_cnf}{by_id} };
    }
    elsif ($cnf{delete_cnf}{find})
    {
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
                my ($html, undef, $status) = get_thread($engine, $get_task, $chan, \%local_delete_cnf);
                echo_msg("Thread $thread downloaded: $status");
                 
                %all_posts = (%all_posts, $engine->find_all_replies($chan, html => $html));
            }
        }
        #-- Search thread on the pages
        if ($cnf{delete_cnf}{page})
        {
            for my $page (@{ $cnf{delete_cnf}{page} })
            {
                my %local_delete_cnf = %{ $cnf{delete_cnf} }; 
                $local_delete_cnf{page} = $page;
                 
                #-- Get the page
                my ($html, undef, $status) = get_page($engine, $get_task, $chan, \%local_delete_cnf);
                echo_msg("Page $page downloaded: $status");
                 
                %all_posts = (%all_posts, $engine->find_all_threads($chan, html => $html));
            }
        }
        unless ($cnf{delete_cnf}{page} || $cnf{delete_cnf}{thread})
        {
            Carp::croak("Options 'thread' or/and 'page' should be specified.");
        }
         
        echo_msg(sprintf "%d posts and threads were found", scalar keys %all_posts);
         
        my $pattern = $cnf{delete_cnf}{find};
        for (keys %all_posts)
        {
            if ($all_posts{$_} =~ /$pattern/mg)
            {
                push @posts_for_del, $_;
            }
        }
        echo_msg(sprintf "%d posts and threads matched the pattern", scalar @posts_for_del);
    }
    else
    {
        Carp::croak("Option 'by_id' or 'find' should be specified.");
    }
     
    for my $postid (@posts_for_del)
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
            my @delete_coro  = grep { $_->desc =~ /delete/ } Coro::State::list;
             
            echo_msg_dbg($DEBUG, sprintf "run: %d; queue: %d", scalar @delete_coro, $delete_queue->size);
                       
            for my $coro (@delete_coro)
            {
                my $now = Time::HiRes::time;
                if ($coro->{timeout_at} && $now > $coro->{timeout_at})
                {
                    echo_proxy('red', $coro->{proxy}, uc($coro->{desc}), '[TIMEOUT]');
                    $coro->cancel('timeout');
                }
            }
        }
    );
     
	#-- Get watcher
    my $gw = AnyEvent->timer(after => 0.5, interval => 2, cb =>
        sub
        {
            my @delete_coro  = grep { $_->desc =~ /delete/ } Coro::State::list;
            my $thrs_available = -1;
            #-- Max delete threads limit
            if ($cnf{max_del_thrs})
            {
                my $n = $cnf{max_del_thrs} - scalar @delete_coro;
                $thrs_available = $n > 0 ? $n : 0;
            }
             
            delete_post($engine, $delete_queue->get, $chan, \%cnf)
                while $delete_queue->size && $thrs_available--;
        }
    );
     
    #-- Exit watchers
    my $ew = AnyEvent->timer(after => 1, interval => 2, cb =>
        sub
        {
            my @delete_coro  = grep { $_->desc =~ /delete/ } Coro::State::list;
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
