use strict;
use Image::OCR::Tesseract 'get_ocr';

sub decode_captcha($$)
{
    my ($captcha_decode, $file_path) = @_;
    my $text = get_ocr($file_path);
    $text =~ s/^\s*//;
    $text =~ s/\s*$//;
    $text =~ s/\n//;
    return $text;
}

sub abuse($$) { }
 
1;
