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
            echo_msg(1, "Downloading $thread thread...");
            my ($html, undef, $status) = $engine->get_thread($get_task, \%local_delete_cnf);
            echo_msg(1, "Thread $thread downloaded: $status");

            %all_posts = (%all_posts, $engine->get_all_replies($html));
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
            echo_msg(1, "Downloading $page page...");
            my ($html, undef, $status) = $engine->get_page($get_task, \%local_delete_cnf);
            echo_msg(1, "Page $page downloaded: $status");

            %all_posts = (%all_posts, $engine->get_all_threads($html));
        }
    }
    unless ($cnf{delete_cnf}{page} || $cnf{delete_cnf}{thread})
    {
        Carp::croak("Options 'thread' or/and 'page' should be specified.");
    }

    echo_msg(1, sprintf "%d posts and threads were found", scalar keys %all_posts);

    my $pattern = $cnf{delete_cnf}{find};
    for (keys %all_posts)
    {
        if ($all_posts{$_} =~ /$pattern/mg)
        {
            push @deletion_posts, $_;
        }
    }
    echo_msg(1, sprintf "%d posts and threads matched the pattern", scalar @deletion_posts);
    return @deletion_posts;
}

1;
