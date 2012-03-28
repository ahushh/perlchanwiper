package PCW::Core::Captcha;

use strict;
use Carp;

use File::Spec;

use Exporter 'import';
our @EXPORT_OK = qw(captcha_recognizer captcha_report_bad);
#------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------

sub captcha_recognizer($$)
{
    my ($captcha_decode, $file_path) = @_;
    my $mode      = $captcha_decode->{mode};
    my $mode_path = File::Spec->catfile('OCR', "$mode.pm");

    Carp::croak("Captcha decode method '$mode' does not exist at $mode_path")
        unless (-e $mode_path);

    require File::Spec->catfile('OCR', "$mode.pm");
    return decode_captcha($captcha_decode, $file_path);
}

sub captcha_report_bad($$)
{
    my ($captcha_decode, $file_path) = @_;
    my $mode = $captcha_decode->{mode};
    require File::Spec->catfile('OCR', "$mode.pm");
    return abuse($captcha_decode, $file_path);
}
1;
