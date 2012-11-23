use v5.12;
use utf8;
use Carp;
use Coro;

sub decode_captcha($$$)
{
    my ($log, $captcha_decode, $file_path) = @_;
    push @{ $captcha_decode->{web}{request} }, $file_path;

    my $text = undef;
    while ( not defined $text )
    {
        $text = $captcha_decode->{web}{answers}{$file_path};
        # use Data::Dumper;
        # print Dumper($captcha_decode->{web});
        Coro::Timer::sleep(1);
    }
    delete $captcha_decode->{web}{answers}{$file_path};
    return $text;
}

sub abuse($$$) {}

1;
