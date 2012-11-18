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

sub captcha_recognizer($$$)
{
    my ($log, $captcha_decode, $file_path) = @_;
    my $mode      = $captcha_decode->{mode};
    my $mode_path = File::Spec->catfile($Bin, 'OCR', "$mode.pm");

    require File::Spec->catfile($Bin, 'OCR', "$mode.pm");
    my $captcha = decode_captcha($log, $captcha_decode, $file_path);
    utf8::decode($captcha);
    return $captcha;
}

sub captcha_report_bad($$$)
{
    my ($log, $captcha_decode, $file_path) = @_;
    my $mode = $captcha_decode->{mode};
    require File::Spec->catfile($Bin, 'OCR', "$mode.pm");
    return abuse($log, $captcha_decode, $file_path);
}

1;
