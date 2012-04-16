package PCW::Modes::Abstract;

#-----------------------------------------------------------------------
use strict;
use autodie;
use Carp;

#------------------------------------------------------------------------------------------------
sub new($%)
{
    my ($class, %args) = @_;
    my $engine   = delete $args{engine};
    my $proxies  = delete $args{proxies};
    my $conf     = delete $args{conf};
    my $log      = delete $args{log};
    my $verbose  = delete $args{verbose}  || 0;
    # TODO: check for errors in the chan-config file
    my @k = keys %args;
    Carp::croak("These options aren't defined: @k")
        if %args;

    my $self = {};
    $self->{engine}  = $engine;
    $self->{proxies} = $proxies;
    $self->{conf}    = $conf;
    $self->{log}     = $log;
    $self->{verbose} = $verbose;
    bless $self, $class;
}
#------------------------------------------------------------------------------------------------
sub get_posts_by_regexp($$$)
{
    my ($self, $proxy, $cnf) =  @_;
    my $log    = $self->{log};
    my $engine = $self->{engine};

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
            $log->msg(2, "Downloading $page page...");
            my ($html, undef, $status) = $engine->get_page($get_task, \%local_cnf);
            $log->msg(2, "Page $page downloaded: $status");

            %threads = (%threads, $engine->get_all_threads($html))
        }
        $log->msg(2, sprintf "%d threads were found", scalar keys %threads);
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
            $log->msg(2, "Downloading $thread thread...");
            my ($html, undef, $status) = $engine->get_thread($get_task, \%local_cnf);
            $log->msg(2, "Thread $thread downloaded: $status");

            my %r    = $engine->get_all_replies($html);
            %replies = (%replies, %r);
            $log->msg(2, sprintf "%d replies were found in $thread thread", scalar keys %r);
        }
        $log->msg(2, sprintf "Total %d replies were found", scalar keys %replies);
    }

    unless ($cnf->{pages} || $cnf->{threads})
    {
        Carp::croak("Options 'threads' or/and 'pages' should be specified.");
    }

    my %all_posts = (%threads, %replies);
    $log->msg(2, sprintf "%d threads and replies were found", scalar keys %all_posts);

    my $pattern = $cnf->{regexp};
    if ($pattern)
    {
        @posts = grep { $all_posts{$_} =~ /$pattern/mg } keys(%all_posts);
        $log->msg(2, sprintf "%d post(s) matched the pattern", scalar @posts);
    }
    else
    {
        @posts = keys %all_posts;
    }
    return @posts;
}

1;
