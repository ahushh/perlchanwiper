package PCW::Captcha;

use strict;
use Carp;

use Exporter 'import';
our @EXPORT_OK = qw(captcha_recognizer captcha_report_bad);
#------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------
 
sub captcha_recognizer($$)
{
    my ($captcha_decode, $file_path) = @_;
    my $mode = $captcha_decode->{mode};
     
    Carp::croak("Captcha decode method '$mode' does not exist")
        unless (-e "OCR/$mode.pm");
     
    require "OCR/$mode.pm";
    return decode_captcha($captcha_decode, $file_path);
}

sub captcha_report_bad($$)
{
    my ($captcha_decode, $file_path) = @_;
    my $mode = $captcha_decode->{mode};
    require "OCR/$mode.pm";
    return abuse($captcha_decode, $file_path);
}
1;
