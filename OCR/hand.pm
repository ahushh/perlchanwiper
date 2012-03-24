use strict;

sub decode_captcha($$)
{
    my ($captcha_decode, $file_path) = @_;
    my $imgv = $captcha_decode->{imgv};
    my $arg  = $captcha_decode->{arg};
    system("$imgv $arg $file_path &");
    print "~~> captcha: ";
    chomp (my $cap_text = <>);
    return $cap_text || undef;
}

sub abuse($$) { }

1;
