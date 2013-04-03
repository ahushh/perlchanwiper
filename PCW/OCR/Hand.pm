package PCW::OCR::Hand;

use v5.12;
use Moo;
use utf8;

sub solve
{
    my ($self, $ocr, $file_path) = @_;
    my $imgv = $ocr->config->{imgv};
    my $arg  = $ocr->config->{arg};
    system("$imgv $arg $file_path &");
    print "~~> captcha: ";
    chomp (my $cap_text = <>);
    return $cap_text;
}

sub report_bad { }

1;
