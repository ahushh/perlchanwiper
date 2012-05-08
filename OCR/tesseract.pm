use strict;
use File::Temp qw(tempdir);
use File::Spec;
use Image::OCR::TesseractX 'get_ocr';

sub decode_captcha($$)
{
    my ($captcha_decode, $file_path) = @_;

    my $tmp  = tempdir('tesseractXXXX',  TMPDIR => 1, CLEANUP => 1);
    my $text;
    eval {
        $text = get_ocr($file_path, $tmp, $captcha_decode->{lang}, $captcha_decode->{config});
    };
    warn $@ if $@;

    #$text =~ s/^\s*//;
    #$text =~ s/\s*$//;
    #$text =~ s/\n//;
    $text =~ s/\s//g;

    return $text || undef;
}

sub abuse($$) { }

1;
