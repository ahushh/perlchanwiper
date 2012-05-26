package PCW::Core::Utils;

use v5.12;
use utf8;
use autodie;
use Carp;

use Exporter 'import';
our @EXPORT_OK =
    qw/random get_proxylist html2text merge_hashes parse_cookies save_file with_coro_timeout unrandomize took shellquote/;

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
    my $ret = &$code;
    $$rtime = sprintf "%.${point}f", time - $$rtime;
    return $ret;
}

#------------------------------------------------------------------------------------------------
# CROSS PLATFORM SHELL QUOTE
#------------------------------------------------------------------------------------------------
use String::ShellQuote qw/shell_quote/;
use Win32::ShellQuote  qw/quote_native/;

sub shellquote($)
{
    my $str = shift;
    if ($^O =~ /linux/)
    {
        return shell_quote $str;
    }
    else
    {
        return quote_native $str;
    }
}

1;
