package PCW::Core::Net;

use v5.12;
use utf8;

use Exporter 'import';
our @EXPORT_OK = qw/http_get http_post/;

use HTTP::Headers;
use Coro::LWP;
eval("use LWP::Protocol::socks;");
warn "LWP::Protocol::socks not installed. Skipping..." if $@;

#------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------
sub http_get(%)
{
    my %p  = @_;
    my $ua = LWP::UserAgent->new();
    $ua->default_headers($p{headers}) if $p{headers};
    $ua->proxy([qw/http https/] => $p{proxy}) if $p{proxy} !~ 'no_proxy';
    $ua->cookie_jar( {} );
    my $response = $ua->get($p{url});

    my $status = $response->status_line;
    utf8::decode($status);
    return { code     => $response->code,
             content  => $response->decoded_content,
             headers  => $response->headers_as_string,
             status   => $status,
             response => $response
           };
}

sub http_post(%)
{
    #use Data::Dumper; say Dumper(@_); exit;
    my %p            = @_;
    my $proxy        = $p{proxy};
    my $url          = $p{url};
    my $headers      = $p{headers};
    my $content      = $p{content};
    my $content_type = $p{content_type} || 'multipart/form-data';

    $content = \%{ $content };
    #-- convert the content to bytes
    for (keys %$content)
    {
        utf8::encode($content->{$_}) unless (ref $content->{$_});
    }
    my $ua = LWP::UserAgent->new();
    $ua->default_headers($headers) if $headers;
    $ua->cookie_jar( {} );
    $ua->proxy([qw/http https/] => $proxy) if $proxy !~ 'no_proxy';
    my $response = $ua->post(
                             $url,
                             'Content_Type' => $content_type,
                             'Content'      => $content,
                            );

    my $status = $response->status_line;
    utf8::decode($status);
    return { code     => $response->code,
             content  => $response->decoded_content,
             headers  => $response->headers_as_string,
             status   => $status,
             response => $response
           };

}

1;
