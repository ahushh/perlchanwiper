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

    my %all_posts = ();
    #-- Search posts in the threads
    if ($cnf->{threads})
    {
        for my $thread (@{ $cnf->{threads} })
        {
            my %local_cnf = %{ $cnf };
            $local_cnf{thread} = $thread;

            #-- Get the thread
            echo_msg(1, "Downloading $thread thread...");
            my ($html, undef, $status) = $engine->get_thread($get_task, \%local_cnf);
            echo_msg(1, "Thread $thread downloaded: $status");

            %all_posts = (%all_posts, $engine->get_all_replies($html));
        }
    }
    #-- Search thread on the pages
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

            %all_posts = (%all_posts, $engine->get_all_threads($html));
        }
    }
    unless ($cnf->{pages} || $cnf->{thread})
    {
        Carp::croak("Options 'threads' or/and 'pages' should be specified.");
    }

    echo_msg(1, sprintf "%d posts and threads were found", scalar keys %all_posts);

    my $pattern = $cnf->{regexp};
    if ($pattern)
    {
        @posts = grep { $all_posts{$_} =~ /$pattern/mg } keys(%all_posts);
        echo_msg(1, sprintf "%d posts and threads matched the pattern", scalar @posts);
    }
    else
    {
        @posts = keys %all_posts;
    }
    return @posts;
}

1;
