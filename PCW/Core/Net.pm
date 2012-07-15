package PCW::Core::Net;

use v5.12;
use utf8;

use Exporter 'import';
our @EXPORT_OK = qw/get_recaptcha http_get http_post/;

use HTTP::Headers;
use Coro::LWP;
eval("use LWP::Protocol::socks;");
warn "LWP::Protocol::socks not installed. Skipping..." if $@;

#------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------
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

sub http_get($$$)
{
    my ($proxy, $url, $headers) = @_;
    my $ua = LWP::UserAgent->new();
    $ua->default_headers($headers) if $headers;
    $ua->proxy([qw/http https/] => $proxy) if $proxy !~ 'no_proxy';
    $ua->cookie_jar( {} );
    my $response = $ua->get($url);

    my $status = $response->status_line;
    utf8::decode($status);
    return $response->decoded_content, $response->headers_as_string, $status;
}

sub http_post($$$$)
{
    #use Data::Dumper; say Dumper(@_); exit;
    my ($proxy, $url, $headers, $content) = @_;
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
                             'Content_Type' => 'multipart/form-data',
                             'Content'      => $content,
                            );

    my $status = $response->status_line;
    utf8::decode($status);
    return $response->code, $response->decoded_content, $status;
}

1;
