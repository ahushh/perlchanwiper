package PCW::OCR::Stub;

use v5.12;
use Moo;

sub solve
{
    my ($self, $ocr, $file_path) = @_;
    $ocr->config->{stub};
}

sub report_bad { }

1;
