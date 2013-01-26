package PCW::Core::Utils;

use v5.12;
use utf8;
use autodie;
use Carp;

use Exporter 'import';
our @EXPORT_OK = qw/
    random
    get_proxylist
    html2text
    merge_hashes
    parse_cookies
    save_file
    with_coro_timeout
    unrandomize
    took
    shellquote
    readfile
    curry
    get_posts_ids
    get_posts_bodies
    get_recaptcha
    get_yacaptcha
/;

#------------------------------------------------------------------------------------------------
# CAPTCHA
#------------------------------------------------------------------------------------------------
use HTTP::Headers;
use Coro::LWP;
eval("use LWP::Protocol::socks;");
warn "LWP::Protocol::socks not installed. Skipping..." if $@;

sub get_yacaptcha($$)
{
    my ($proxy, $key) = @_;
    my $img_url = 'http://i.captcha.yandex.net/image?key='. $key;
    my $ua = LWP::UserAgent->new(
    'agent' => 'Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US) AppleWebKit/A.B (KHTML, like Gecko) Chrome/X.Y.Z.W Safari/A.B.',
                                );
    $ua->proxy([qw/http https/] => $proxy) if $proxy !~ 'no_proxy';
    $ua->cookie_jar( {} );
    my $response = $ua->get($img_url);
    return $response;
}

sub get_recaptcha($$)
{
    my ($proxy, $key) = @_;
    my $key_url = 'https://www.google.com/recaptcha/api/challenge?k=';
    my $img_url = 'https://www.google.com/recaptcha/api/image?c=';
    my $google_headers = {
                          'Host'               =>   'www.google.com',
                          'Referer'            =>   'http://google.com/',
                          'Accept'             =>   '*/*',
                          'Accept-Charset'     =>   'windows-1251,utf-8;q=0.7,*;q=0,7',
                          'Accept-Encoding'    =>   'gzip, deflate',
                          'Accept-Language'    =>   'ru-ru,ru;q=0.8,en-us;q=0.5,en;q=0.3',
                          'Connection'         =>   'keep-alive',
                          'Cache-Control'      =>   'max-age=0',
                         };
    my $ua = LWP::UserAgent->new(
                                 'agent'           => 'Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US) AppleWebKit/A.B (KHTML, like Gecko) Chrome/X.Y.Z.W Safari/A.B.',
                                 'default_headers' => HTTP::Headers->new($google_headers),
                                );
    $ua->proxy([qw/http https/] => $proxy) if $proxy !~ 'no_proxy';
    $ua->cookie_jar( {} );
    my $response = $ua->get($key_url . $key);

    return undef
        unless ($response->content =~ /challenge : '(\S+)',/);

    $ua->default_header('Accept' => 'img/png,img/*;q=0.8,*/*;q=0.5');
    $response = $ua->get($img_url . $1);
    return undef if $response->code != 200;
    return $response->decoded_content, 'recaptcha_challenge_field', $1;
}

#------------------------------------------------------------------------------------------------
# CORO TIMEOUT
#------------------------------------------------------------------------------------------------
use Coro;
use Time::HiRes;

sub with_coro_timeout(&$$)
{
    my ($code, $coro, $timeout) = @_;
    $coro->{timeout_at} = Time::HiRes::time() + $timeout;
    my $ret = &$code;
    delete $coro->{timeout_at};
    return $ret;
}

#------------------------------------------------------------------------------------------------
# PROXY
#------------------------------------------------------------------------------------------------
use Coro::LWP;      #-- без подключения этого модуля начинается какая-то хуете с LWP::Simple::get()
use LWP::Simple     qw/get/;
use List::MoreUtils qw/uniq/;

sub get_proxylist($$)
{
    my ($path, $default_proxy_type) = @_;

    $default_proxy_type = 'http'
        unless defined $default_proxy_type;
    my @proxies;
    my $proxy_list;
    if ($path =~ /(https?\:\/\/\S+)/)
    {
        $proxy_list = get($path) or Carp::croak "Couldn't download proxy list from $path\n";
    }
    else
    {
        open(my $fh, '<', $path);
        {
            local $/ = undef;
            $proxy_list = <$fh>;
            close $fh;
        }
    }

    push @proxies, $1
        while $proxy_list =~ /((http|socks4?:\/\/)?         #-- protocol
                                  ((\w|\d)+:(\w|\d)+@)?     #-- user login and password
                                  (\d+\.\d+\.\d+.\d+\:\d+)| #-- e.g. 192.168.1.1:80
                                  ((\w|\d|\.)+\.\w+:\d+)|   #-- e.g. my.awesome.proxy.com:80
                                  (no_proxy))/gsx;
    for (@proxies)
    {
        s/^/$default_proxy_type:\/\//
            unless /http|socks/;
    }

    uniq @proxies;
}

#------------------------------------------------------------------------------------------------
# RANDOM NUMBER
#------------------------------------------------------------------------------------------------
sub random($$)
{
    my ($min, $max) = @_;
    return $min + int(rand($max - $min + 1));
}

#------------------------------------------------------------------------------------------------
# STRIP ALL HTML CODE
#------------------------------------------------------------------------------------------------
use HTML::Entities;

sub html2text($)
{
    my $html = shift;
    decode_entities($html);
    $html =~ s!<style.+?>.*?</style>!!sg;
    $html =~ s!<script.+?>.*?</script>!!sg;
    $html =~ s/{.*?}//sg;       #-- style
    $html =~ s/<!--.*?-->//sg;	#-- comments
    $html =~ s/<.*?>//sg;       #-- tags
    $html =~ s/\s+/ /sg;
    $html =~ s/^\s//;
    $html =~ s/\s&//;
    return $html;
}

#------------------------------------------------------------------------------------------------
# CREATE A TEMP FILE AND RETURN ITS PATH
#------------------------------------------------------------------------------------------------
use File::Temp qw/tempfile/;

sub save_file($$)
{
    my ($content, $type) = @_;
    my ($fh, $filename) = tempfile(UNLINK => 1, SUFFIX => ".$type");
    print $fh $content;
    close $fh;
    return $filename;
}

#------------------------------------------------------------------------------------------------
# FIND COOKIES IN THE HEADER STRING
#------------------------------------------------------------------------------------------------
sub parse_cookies($$)
{
    my ($list_of_nedeed_cookies, $headers) = @_;
    my $cookies;
    for (@{ $list_of_nedeed_cookies })
    {
        return undef unless $headers =~ /($_=[a-zA-Z0-9]+?(;|\n))/g;
        $cookies .= "$1 ";
    }
    return $cookies;
}

#------------------------------------------------------------------------------------------------
# MERGE HASHES
#------------------------------------------------------------------------------------------------
sub merge_hashes($$)
{
    my ($content, $fields) = @_;
    my %gen_content;
    for (keys %$content)
    {
        $gen_content{$fields->{$_}} = $content->{$_};
    }

    return \%gen_content;
}

#------------------------------------------------------------------------------------------------
# REPLACE THE ARRAY REF WITH A RANDOM SCALAR
#------------------------------------------------------------------------------------------------
use Data::Random qw/rand_set/;

sub unrandomize($)
{
    my $h        = shift;
    my %new_hash = {};
    for (keys %$h)
    {
        if (ref($h->{$_}) eq 'ARRAY')
        {
            $new_hash{$_} = ${ rand_set(set => $h->{$_}) };
        }
        else
        {
            $new_hash{$_} = $h->{$_};
        }
    }
    return \%new_hash;
}

#------------------------------------------------------------------------------------------------
# MEASURE EXECUTION TIME OF CODE 
#------------------------------------------------------------------------------------------------
use Time::HiRes qw/time/;

sub took(&$;$)
{
    my ($code, $rtime, $point) = @_;
    $point  = 3 unless $point;
    $$rtime = time;
    my @ret = &$code;
    $$rtime = sprintf "%.${point}f", time - $$rtime;
    return wantarray() ? @ret : shift(@ret);
}

#------------------------------------------------------------------------------------------------
# CROSS PLATFORM SHELL QUOTE
#------------------------------------------------------------------------------------------------
sub shellquote($)
{
    my $str = shift;
    if ($^O =~ /linux/)
    {
        eval q{
            use String::ShellQuote qw/shell_quote/;
            return shell_quote "$str";
        } or Carp::croak $@;
    }
    else
    {
        eval q{
            use Win32::ShellQuote  qw/quote_native/;
            return quote_native "$str";
        } or Carp::croak $@;
    }
}

#------------------------------------------------------------------------------------------------
# JUST READ FILE
#------------------------------------------------------------------------------------------------
sub readfile($;$)
{
    my ($path, $enc) = @_;
    open my $fh, '<'. ($enc ? ":$enc" : ''), $path;
    local $/ = undef unless wantarray();
    my @data = <$fh>;
    close $fh;
    return (wantarray() ? @data : shift(@data));
}

#------------------------------------------------------------------------------------------------
# PARTIAL FUNCTION APPLICATION
#------------------------------------------------------------------------------------------------
sub curry($@)
{
    my ($code, @argv) = (shift, @_);
    return sub { &$code(@argv, @_) };
}

#------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------
sub get_page($$$$)
{
    my ($engine, $get_task, $cnf, $page) = @_;
    my $log          = $engine->{log};
    my %local_cnf    = %{ $cnf };
    $local_cnf{page} = $page;

    #-- Get the page
    my $took;
    $log->msg('DATA_LOADING', "Downloading $page page...");
    my ($html, undef, $status) = took { $engine->get_page($get_task, \%local_cnf) } \$took;
    $log->msg('DATA_LOADED', "Page $page downloaded: $status (took $took sec.)");

    my %t    = $engine->get_all_threads($html);
    $log->msg('DATA_FOUND', sprintf "%d threads were found on $page page", scalar keys %t);
    return %t;
}

sub get_thread($$$$)
{
    my ($engine, $get_task, $cnf, $thread) = @_;
    my $log            = $engine->{log};
    my %local_cnf      = %{ $cnf };
    $local_cnf{thread} = $thread;

    #-- Get the thread
    my $took;
    $log->msg('DATA_LOADING', "Downloading $thread thread...");
    my ($html, undef, $status) = took { $engine->get_thread($get_task, \%local_cnf) } \$took;
    $log->msg('DATA_LOADED', "Thread $thread downloaded: $status (took $took sec.)");

    my %r    = $engine->get_all_replies($html);
    $log->msg('DATA_FOUND', sprintf "%d replies were found in $thread thread", scalar keys %r);
    return %r;
}

sub get_posts_bodies($$$)
{
    my ($engine, $proxy, $cnf) =  @_;
    my $log    = $engine->{log};

    my $get_task = {
        proxy    => $proxy,
    };

    #-- Search thread on the pages
    my %threads     = ();
    if (defined $cnf->{threads} and defined $cnf->{threads}{pages})
    {
        for my $page (@{ $cnf->{threads}{pages} })
        {
            %threads = (%threads, get_page($engine, $get_task, $cnf, $page) );
        }
        $log->msg('DATA_FOUND', sprintf "Total %d threads were found", scalar keys %threads);
        #-- Filter by regexp
        if (my $pattern = $cnf->{threads}{regexp})
        {
            %threads = map { ($_, $threads{$_}) if $threads{$_} =~ /$pattern/sg } keys(%threads);
            $log->msg('DATA_MATCHED', sprintf "%d thread(s) matched the pattern", scalar keys(%threads));
        }
    }
    if ($cnf->{threads}{number} > 0)
    {
        my %t = ();
        for (1..$cnf->{threads}{number})
        {
            my @k = keys %threads;
            last if $_ > scalar(@k);
            my $k = ${ rand_set( set => \@k ) };
            %t    = (%t, $k, $threads{$k});
        }
        %threads = %t;
    }
    #-- Search posts in the threads
    my %replies     = ();
    if (-e $cnf->{replies}{threads})
    {
        my $data = readfile($cnf->{replies}{threads}, 'utf8');
        %replies = $engine->get_all_replies($data);
        $log->msg('DATA_FOUND', sprintf "'%s' thread loaded.", $cnf->{replies}{threads} );
        #-- Filter by regexp
        if (my $pattern = $cnf->{replies}{regexp})
        {
            %replies = map { ($_, $replies{$_}) if $replies{$_} =~ /$pattern/sg } keys(%replies);
            $log->msg('DATA_MATCHED', sprintf "%d replies matched the pattern", scalar keys(%replies));
        }
    }
    else
    {
        for my $thread ( $cnf->{replies}{threads} eq 'found' ? keys(%threads) : @{ $cnf->{replies}{threads} } )
        {
           %replies = (%replies, get_thread($engine, $get_task, $cnf, $thread));
        }
        #-- Filter by regexp
        if (my $pattern = $cnf->{replies}{regexp})
        {
            %replies = map { ($_, $replies{$_}) if $replies{$_} =~ /$pattern/sg } keys(%replies);
            $log->msg('DATA_MATCHED', sprintf "%d replies matched the pattern", scalar keys(%replies));
        }
    }
    $log->msg('DATA_FOUND_ALL', sprintf "Total %d post(s) were found", scalar keys(%replies));
    return %replies;
}

sub get_posts_ids($$$)
{
    my ($engine, $proxy, $cnf) =  @_;
    my $log    = $engine->{log};

    my $get_task = {
        proxy    => $proxy,
    };

    #-- Search thread on the pages
    my %threads     = ();
    my @threads     = (); #-- only ID's
    my @thr_in_text = ();
    if ($cnf->{threads})
    {
        for my $page (@{ $cnf->{threads}{pages} })
        {
            %threads = (%threads, get_page($engine, $get_task, $cnf, $page) );
        }
        $log->msg('DATA_FOUND', sprintf "Total %d threads were found", scalar keys %threads);
        #-- Filter by regexp
        if (my $pattern = $cnf->{threads}{regexp})
        {
            @threads = grep { $threads{$_} =~ /$pattern/sg } keys(%threads);
            $log->msg('DATA_MATCHED', sprintf "%d thread(s) matched the pattern", scalar @threads);
        }
        else
        {
            @threads = keys(%threads);
        }
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
            $log->msg('DATA_FOUND', sprintf "%d posts(s) found in text of threads", scalar @thr_in_text);
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
            %replies = (%replies, get_thread($engine, $get_task, $cnf, $thread));
        }
        $log->msg('DATA_FOUND', sprintf "Total %d replies were found", scalar keys %replies);
        #-- Filter by regexp
        if (my $pattern = $cnf->{replies}{regexp})
        {
            @replies = grep { $replies{$_} =~ /$pattern/sg } keys(%replies);
            $log->msg('DATA_MATCHED', sprintf "%d replies matched the pattern", scalar @replies);
        }
        else
        {
            @replies = keys(%replies);
        }
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
            $log->msg('DATA_FOUND', sprintf "%d posts(s) found in text of replies", scalar @rep_in_text);
        }
    }
    my @posts = ( @rep_in_text, @thr_in_text,
                ( $cnf->{replies}{include}  ? @replies : () ),
                ( $cnf->{threads}{include}  ? @threads : () ) );

    $log->msg('DATA_FOUND_ALL', sprintf "Total %d post(s) were found", scalar @posts);
    return undef unless @posts;

    given ($cnf->{take})
    {
        when ('random')
        {
            my $r = ${ rand_set(set => \@posts) };
            $log->msg('DATA_TAKE_IDS', "Take a random ID: $r");
            return $r;
        }
        when ('last')
        {
            my @last;
            my @p = sort {$a <=> $b} @posts;
            push @last, pop(@p);
            $log->msg('DATA_TAKE_IDS', "Take the last ID: @last");
            return @last;
        }
        when ('all')
        {
            return @posts;
        }
        default
        {
            return @posts;
        }
    }
}

1;
