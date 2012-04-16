package PCW::Core::Utils;

use strict;
use autodie;
use Carp;

use Exporter 'import';
our @EXPORT_OK = qw(random get_proxylist html2text merge_hashes parse_cookies save_file with_coro_timeout);

#------------------------------------------------------------------------------------------------
# Importing utility packages
#------------------------------------------------------------------------------------------------
use Data::Random qw(rand_set);

#------------------------------------------------------------------------------------------------
# CORO TIMEOUT
#------------------------------------------------------------------------------------------------
use Coro;
#use Coro::State;
#use LWP::UserAgent;
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
use LWP::Simple qw(get);
use List::MoreUtils qw(uniq);

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
# SAVE FILE
#------------------------------------------------------------------------------------------------
use File::Temp qw(tempfile);

sub save_file($$)
{
    my ($content, $type) = @_;
    my ($fh, $filename) = tempfile(UNLINK => 1, SUFFIX => ".$type");
    print $fh $content;
    close($fh);
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
        if (ref($content->{$_}) eq 'ARRAY')
        {
            $gen_content{$fields->{$_}} = ${ rand_set(set => $content->{$_}) };
        }
        else
        {
            $gen_content{$fields->{$_}} = $content->{$_};
        }
    }

    return \%gen_content;
}

1;
