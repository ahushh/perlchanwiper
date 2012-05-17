use v5.12;
use utf8;

use Carp;
use File::Temp qw/tempdir tempfile/;
use File::Spec;

use File::Which qw/which/;
use String::ShellQuote qw/shell_quote/;
#--------------------------------------------------------------------------------------------
my $tesseract = which('tesseract') || Carp::croak("Coudn't find bin path to tesseract.");
my $convert   = which('convert')   || Carp::croak("Coudn't find bin path to convert.");
my $tmpdir    = tempdir('tesseractXXXX',  TMPDIR => 1, CLEANUP => 1);
#--------------------------------------------------------------------------------------------
sub _convert2tiff($)
{
    my $source = shift;
    my $dest   = File::Spec->catfile($tmpdir, rand().'.tif');
    system( $convert, $source, '-compress', 'none', '+matte',  $dest);
    Carp::croak $? if $?;
    return $dest;
}

sub _get_ocr($;$$)
{
    my ($img, $lang, $config) = @_;
    my $tif = _convert2tiff $img;
    my $cmd = 
        ( sprintf '%s %s %s',
          $tesseract,
          shell_quote($tif),
          shell_quote($tif)
        ) .
        ( defined $lang   ? " -l $lang"        : '' ) .
        ( defined $config ? " nobatch $config" : '' ) .
          " 2>/dev/null 1>&2";

    system $cmd;
    my $text;
    open my $fh, '<', "$tif.txt";
    {
        local $/ = undef;;
        $text = <$fh>;
        close $fh;
    }
    return $text;
}
#--------------------------------------------------------------------------------------------
sub decode_captcha($$)
{
    my ($captcha_decode, $file_path) = @_;
    my $text;
    eval {
        $text = _get_ocr($file_path, $captcha_decode->{lang}, $captcha_decode->{config});
    };
    warn $@ if $@;
    #warn "Error while recognizing a captcha" if $@;

    #$text =~ s/^\s*//;
    #$text =~ s/\s*$//;
    #$text =~ s/\n//;
    $text =~ s/\s//g;

    return $text || undef;
}

sub abuse($$) { }

1;
