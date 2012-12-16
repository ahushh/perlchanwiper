package PCW::Core::Captcha;

use v5.12;
use utf8;
use Carp;

use Exporter 'import';
our @EXPORT_OK = qw/captcha_recognizer captcha_report_bad/;

use FindBin qw/$Bin/;
use File::Spec;

#------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------

sub captcha_recognizer($$$$)
{
    my ($ocr, $log, $captcha_decode, $file_path) = @_;
    my $mode      = $captcha_decode->{mode};
    my $after     = $captcha_decode->{after} || sub { $_[0] };
    my $mode_path = File::Spec->catfile($Bin, 'OCR', "$mode.pm");

    require File::Spec->catfile($Bin, 'OCR', "$mode.pm");
    my $captcha = decode_captcha($ocr, $log, $captcha_decode, $file_path);
    $captcha = &$after($captcha);
    utf8::decode($captcha);
    return $captcha;
}

sub captcha_report_bad($$$$)
{
    my ($ocr, $log, $captcha_decode, $file_path) = @_;
    my $mode = $captcha_decode->{mode};
    require File::Spec->catfile($Bin, 'OCR', "$mode.pm");
    return abuse($ocr, $log, $captcha_decode, $file_path);
}

1;
