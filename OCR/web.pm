use v5.12;
use utf8;
use Coro;

sub decode_captcha($$$$)
{
    my ($ocr, $log, $captcha_decode, $file_path) = @_;
    push @{ $ocr->{web}{request} }, $file_path;

    #use Data::Dumper;
    #print "before:\n";
    #print Dumper($ocr->{web});
    my $text = undef;
    while ( not defined $text )
    {
        $text = $ocr->{web}{answers}{$file_path};
        Coro::Timer::sleep(1);
    }
    #print "after:\n";
    #print Dumper($ocr->{web});
    delete $ocr->{web}{answers}{$file_path};
    return $text;
}

sub abuse($$$$) {}

1;
