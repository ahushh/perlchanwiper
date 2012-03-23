package PCW::Modes::Common;

#-----------------------------------------------------------------------
# Функции, общие для всех модов
#-----------------------------------------------------------------------

use strict;
use autodie;
use Carp;

use Exporter 'import';
our @EXPORT_OK = qw(get_posts_by_regexp);

#------------------------------------------------------------------------------------------------
# Package Variables
#------------------------------------------------------------------------------------------------
our $LOGLEVEL = 0;
our $VERBOSE  = 0;

#------------------------------------------------------------------------------------------------
# Importing internal PCW packages
#------------------------------------------------------------------------------------------------
use PCW::Core::Log   qw(echo_msg echo_proxy);

#------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------
sub get_posts_by_regexp($$%)
{
    my ($proxy, $engine, $cnf) =  @_;

    my @posts;
    my $get_task = {
        proxy    => $proxy,
    };

    #-- Search thread on the pages
    my %threads = ();
    if ($cnf->{pages})
    {
        for my $page (@{ $cnf->{pages} })
        {
            my %local_cnf = %{ $cnf };
            $local_cnf{page} = $page;

            #-- Get the page
            echo_msg(1, "Downloading $page page...");
            my ($html, undef, $status) = $engine->get_page($get_task, \%local_cnf);
            echo_msg(1, "Page $page downloaded: $status");

            %threads   = (%threads, $engine->get_all_threads($html))
        }
        echo_msg(1, sprintf "%d threads were found", scalar keys %threads);
    }
    #-- Search posts in the threads
    my %replies = ();
    if ($cnf->{threads} || ($cnf->{in_found_thrs} && $cnf->{pages}))
    {
        my @found_thrs = ();
        if ($cnf->{in_found_thrs})
        {
            my $pattern = $cnf->{in_found_thrs};
            @found_thrs = grep { $threads{$_} =~ /$pattern/mg } keys(%threads);
        }
        for my $thread (@{ $cnf->{threads} }, @found_thrs)
        {
            my %local_cnf = %{ $cnf };
            $local_cnf{thread} = $thread;

            #-- Get the thread
            echo_msg(1, "Downloading $thread thread...");
            my ($html, undef, $status) = $engine->get_thread($get_task, \%local_cnf);
            echo_msg(1, "Thread $thread downloaded: $status");

            my %r    = $engine->get_all_replies($html);
            %replies = (%replies, %r);
            echo_msg(1, sprintf "%d replies were found in $thread thread", scalar keys %r);
        }
        echo_msg(1, sprintf "Total %d replies were found", scalar keys %replies);
    }

    unless ($cnf->{pages} || $cnf->{threads})
    {
        Carp::croak("Options 'threads' or/and 'pages' should be specified.");
    }

    my %all_posts = (%threads, %replies);
    echo_msg(1, sprintf "%d threads and replies were found", scalar keys %all_posts);

    my $pattern = $cnf->{regexp};
    if ($pattern)
    {
        @posts = grep { $all_posts{$_} =~ /$pattern/mg } keys(%all_posts);
        echo_msg(1, sprintf "%d post(s) matched the pattern", scalar @posts);
    }
    else
    {
        @posts = keys %all_posts;
    }
    return @posts;
}

1;
