package PCW::Modes::Base;

use v5.12;
use utf8;
use Carp;

#------------------------------------------------------------------------------------------------
sub new($%)
{
    my ($class, %args) = @_;
    my $engine   = delete $args{engine};
    my $proxies  = delete $args{proxies};
    my $conf     = delete $args{conf};
    my $log      = delete $args{log};
    my $verbose  = delete $args{verbose} || 0;

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

    my $get_task = {
        proxy    => $proxy,
    };

    #-- Search thread on the pages
    my %threads = ();
    my @threads = ();
    if ($cnf->{threads})
    {
        for my $page (@{ $cnf->{threads}{pages} })
        {
            my %local_cnf = %{ $cnf };
            $local_cnf{page} = $page;

            #-- Get the page
            $log->msg(3, "Downloading $page page...");
            my ($html, undef, $status) = $engine->get_page($get_task, \%local_cnf);
            $log->msg(2, "Page $page downloaded: $status");

            my %t    = $engine->get_all_threads($html);
            %threads = (%threads, %t);
            $log->msg(3, sprintf "%d threads were found on $page page", scalar keys %t);
        }
        $log->msg(2, sprintf "Total %d threads were found", scalar keys %threads);
        #-- Filter by regexp
        my $pattern = $cnf->{threads}{regexp};
        @threads = grep { $threads{$_} =~ /$pattern/sg } keys(%threads);
        $log->msg(2, sprintf "%d thread(s) matched the pattern", scalar @threads);
    }
    #-- Search posts in the threads
    my %replies = ();
    my @replies = ();
    if ($cnf->{replies})
    {
        for my $thread ( $cnf->{replies}{threads} eq 'found' ? @threads : @{ $cnf->{replies}{threads} } )
        {
            my %local_cnf = %{ $cnf };
            $local_cnf{thread} = $thread;

            #-- Get the thread
            $log->msg(3, "Downloading $thread thread...");
            my ($html, undef, $status) = $engine->get_thread($get_task, \%local_cnf);
            $log->msg(2, "Thread $thread downloaded: $status");

            my %r    = $engine->get_all_replies($html);
            %replies = (%replies, %r);
            $log->msg(3, sprintf "%d replies were found in $thread thread", scalar keys %r);
        }
        $log->msg(2, sprintf "Total %d replies were found", scalar keys %replies);
        #-- Filter by regexp
        my $pattern = $cnf->{replies}{regexp};
        @replies = grep { $replies{$_} =~ /$pattern/sg } keys(%replies);
        $log->msg(2, sprintf "%d replies matched the pattern", scalar @replies);
    }
    my @posts = ( @replies,
                  ( $cnf->{threads}{include} ? @threads : () ) );

    $log->msg(2, sprintf "Total %d post(s) to delete were found", scalar @posts);
    return @posts;
}

1;
