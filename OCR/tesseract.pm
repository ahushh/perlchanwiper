use strict;
use File::Temp qw(tempdir);
use File::Spec;
use Image::OCR::TesseractX 'get_ocr';

sub decode_captcha($$)
{
    my ($captcha_decode, $file_path) = @_;
    my $tmp  = tempdir('tesseractXXXX',  TMPDIR => 1, CLEANUP => 1);
    my $text = get_ocr($file_path, $tmp, $captcha_decode->{lang}, $captcha_decode->{config});

    $text =~ s/^\s*//;
    $text =~ s/\s*$//;
    $text =~ s/\n//;

    return $text;
}

sub abuse($$) { }

1;
