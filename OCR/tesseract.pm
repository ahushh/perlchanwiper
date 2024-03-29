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
    my $dest   = File::Spec->catfile($tmpdir, rand().'.tiff');
    my $cmd    = sprintf "%s %s %s %s %s %s %s 2>&1",
                shellquote($convert),
                shellquote($source),
                '-compress',
                'none',
                '+matte',
                '-flatten',
                shellquote($dest);
    my $err    = `$cmd`;
    die "Error while converting a captcha to tiff:$err" if $?;
    return $dest;
}

sub _get_ocr($;%)
{
    my ($img, %cnf) = @_;
    my $tiff = _convert2tiff $img;
    my $cmd = 
        ( sprintf '%s %s %s',
          shellquote($tesseract),
          shellquote($tiff),
          shellquote($tiff)
        ) .
        ( defined $cnf{lang}   ? " -l $cnf{lang}"        : ''       ) .
        ( defined $cnf{psm}    ? " -psm $cnf{psm}"       : ''       ) .
        ( defined $cnf{config} ? " nobatch $cnf{config}" : ''       ) .
        ( $^O =~ /linux/       ? " 2>/dev/null 1>&2"     : ' > NUL' ) ;

    my $err = `$cmd`;
    die "Error while getting tesseract OCR: $err" if $?;
    return readfile("$tiff.txt") || '';
}
#--------------------------------------------------------------------------------------------
sub decode_captcha($$$$)
{
    my ($ocr, $log, $captcha_decode, $file_path) = @_;
    my $text;
    eval {
        $text = _get_ocr($file_path,
                         lang   => $captcha_decode->{lang},
                         config => $captcha_decode->{config},
                         psm    => $captcha_decode->{psm},
                        );
    };
    if ($@)
    {
        $log->msg('OCR_ERROR', $@, 'DECODE CAPTCHA', 'red');
        return undef;
    }
    return $text;
}

sub abuse($$$$) { }

1;
