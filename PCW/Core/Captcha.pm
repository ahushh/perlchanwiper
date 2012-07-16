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

    Carp::croak("Captcha decode method '$mode' does not exist at $mode_path")
        unless (-e $mode_path);

    require File::Spec->catfile($Bin, 'OCR', "$mode.pm");
    return decode_captcha($log, $captcha_decode, $file_path);
}

sub captcha_report_bad($$$)
{
    my ($log, $captcha_decode, $file_path) = @_;
    my $mode = $captcha_decode->{mode};
    require File::Spec->catfile($Bin, 'OCR', "$mode.pm");
    return abuse($log, $captcha_decode, $file_path);
}

1;
