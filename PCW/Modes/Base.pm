package PCW::Modes::Base;

use v5.12;
use utf8;
use Carp;

use PCW::Core::Utils qw/took/;
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
    my %threads     = ();
    my @threads     = ();
    my @thr_in_text = ();
    if ($cnf->{threads})
    {
        for my $page (@{ $cnf->{threads}{pages} })
        {
            my %local_cnf = %{ $cnf };
            $local_cnf{page} = $page;

            #-- Get the page
            my $took;
            $log->msg(3, "Downloading $page page...");
            my ($html, undef, $status) = took { $engine->get_page($get_task, \%local_cnf) } \$took;
            $log->msg(2, "Page $page downloaded: $status (took $took sec.)");

            my %t    = $engine->get_all_threads($html);
            %threads = (%threads, %t);
            $log->msg(3, sprintf "%d threads were found on $page page", scalar keys %t);
        }
        $log->msg(2, sprintf "Total %d threads were found", scalar keys %threads);
        #-- Filter by regexp
        my $pattern = $cnf->{threads}{regexp};
        @threads = grep { $threads{$_} =~ /$pattern/sg } keys(%threads);
        $log->msg(2, sprintf "%d thread(s) matched the pattern", scalar @threads) if $pattern;
        #-- Find a thread's ID in the text of thread 
        if ($cnf->{threads}{in_text})
        {
            my $pattern = $cnf->{threads}{in_text};
            for (@threads)
            {
                while ($threads{$_} =~ /$pattern/sg)
                {
                    push @thr_in_text, $+{post};
                }
            }
            $log->msg(2, sprintf "%d posts(s) found in text of threads", scalar @thr_in_text);
        }
    }
    #-- Search posts in the threads
    my %replies     = ();
    my @replies     = ();
    my @rep_in_text = ();
    if ($cnf->{replies})
    {
        for my $thread ( $cnf->{replies}{threads} eq 'found' ? @threads : @{ $cnf->{replies}{threads} } )
        {
            my %local_cnf = %{ $cnf };
            $local_cnf{thread} = $thread;

            #-- Get the thread
            my $took;
            $log->msg(3, "Downloading $thread thread...");
            my ($html, undef, $status) = took { $engine->get_thread($get_task, \%local_cnf) } \$took;
            $log->msg(2, "Thread $thread downloaded: $status (took $took sec.)");

            my %r    = $engine->get_all_replies($html);
            %replies = (%replies, %r);
            $log->msg(3, sprintf "%d replies were found in $thread thread", scalar keys %r);
        }
        $log->msg(2, sprintf "Total %d replies were found", scalar keys %replies);
        #-- Filter by regexp
        my $pattern = $cnf->{replies}{regexp};
        @replies = grep { $replies{$_} =~ /$pattern/sg } keys(%replies);
        $log->msg(2, sprintf "%d replies matched the pattern", scalar @replies) if $pattern;
        #-- Find a thread's ID in the text of reply 
        if ($cnf->{replies}{in_text})
        {
            my $pattern = $cnf->{replies}{in_text};
            for (@replies)
            {
                while ($replies{$_} =~ /$pattern/sg)
                {
                    push @rep_in_text, $+{post};
                }
            }
            $log->msg(2, sprintf "%d posts(s) found in text of replies", scalar @rep_in_text);
        }
    }
    my @posts = ( @rep_in_text, @thr_in_text,
                  ( $cnf->{replies}{include} ? @replies : () ),
                  ( $cnf->{threads}{include} ? @threads : () ) );

    $log->msg(2, sprintf "Total %d post(s) were found", scalar @posts);
    
    if ($cnf->{take_last})
    {
        my @last;
        my @p = sort {$a <=> $b} @posts;
        push @last, pop(@p);
        $log->msg(2, "Take the last ID: @last");
        return @last;
    }
    return @posts;
}

1;
