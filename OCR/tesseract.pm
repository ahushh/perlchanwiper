use v5.12;
use utf8;

use File::Temp qw/tempdir tempfile/;
use File::Spec;

use File::Which      qw/which/;
use PCW::Core::Utils qw/shellquote readfile/;
#--------------------------------------------------------------------------------------------
my $tesseract = which('tesseract') || Carp::croak("Coudn't find bin path to tesseract.");
my $convert   = which('convert')   || Carp::croak("Coudn't find bin path to convert.");
my $tmpdir    = tempdir('tesseractXXXX',  TMPDIR => 1, CLEANUP => 1);
#--------------------------------------------------------------------------------------------
sub _convert2tiff($)
{
    my $source = shift;
    my $dest   = File::Spec->catfile($tmpdir, rand().'.tif');
    my $cmd    = sprintf "%s %s %s %s %s %s 2>&1",
                shellquote($convert),
                shellquote($source),
                '-compress',
                'none',
                '+matte',
                shellquote($dest);
    my $err    = `$cmd`;
    die "Error while converting a captcha to tif:$err" if $?;
    return $dest;
}

sub _get_ocr($;$$)
{
    my ($img, $lang, $config) = @_;
    my $tif = _convert2tiff $img;
    my $cmd = 
        ( sprintf '%s %s %s',
          shellquote($tesseract),
          shellquote($tif),
          shellquote($tif)
        ) .
        ( defined $lang   ? " -l $lang"         : '' ) .
        ( defined $config ? " nobatch $config"  : '' ) .
        ( $^O =~ /linux/  ? " 2>/dev/null 1>&2" : ' > NUL' );

    my $err = `$cmd`;
    die "Error while getting tesseract OCR: $err" if $?;
    return readfile("$tif.txt") || '';
}
#--------------------------------------------------------------------------------------------
sub decode_captcha($$$)
{
    my ($log, $captcha_decode, $file_path) = @_;
    my $after = $captcha_decode->{after};
    my $text;
    eval {
        $text = _get_ocr($file_path, $captcha_decode->{lang}, $captcha_decode->{config});
    };
    if ($@)
    {
        $log->msg(1, $@, 'DECODE CAPTCHA', 'red');
        return undef;
    }
    return &$after($text);
}

sub abuse($$$) { }

1;
