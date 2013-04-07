package PCW::OCR::Tesseract;

use v5.12;
use Moo;
use utf8;

use File::Temp qw/tempdir tempfile/;
use File::Spec;

use File::Which      qw/which/;
use PCW::Core::Utils qw/shellquote readfile/;
#--------------------------------------------------------------------------------------------

has 'tesseract' => (
    is      => 'ro',
    default => sub { which('tesseract') || Carp::croak("Coudn't find bin path to tesseract.") },
);

has 'convert' => (
    is      => 'ro',
    default => sub { which('convert')   || Carp::croak("Coudn't find bin path to convert.") },
);

has 'tmpdir' => (
    is      => 'ro',
    default => sub { tempdir('tesseractXXXX',  TMPDIR => 1, CLEANUP => 1) },
);
#--------------------------------------------------------------------------------------------
sub _convert2tiff
{
    my ($self, $source) = @_;
    my $dest   = File::Spec->catfile($self->tmpdir, rand().'.tiff');
    my $cmd    = sprintf "%s %s %s %s %s %s %s 2>&1",
                shellquote($self->convert),
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

sub _get_ocr
{
    my ($self, $ocr, $img) = @_;
    my $tiff = $self->_convert2tiff($img);
    my $cmd  =
        ( sprintf '%s %s %s',
          shellquote($self->tesseract),
          shellquote($tiff),
          shellquote($tiff)
        ) .
        ( defined $ocr->config->{lang}   ? (" -l "     . $ocr->config->{lang})   : '' ) .
        ( defined $ocr->config->{psm}    ? (" -psm "   . $ocr->config->{psm})    : '' ) .
        ( defined $ocr->config->{config} ? (" nobatch ". $ocr->config->{config}) : '' ) .
        ( $^O =~ /linux/                  ? " 2>/dev/null 1>&2"                  : ' > NUL' ) ;

    my $err = `$cmd`;
    die "Error while getting tesseract OCR: $err" if $?;
    return readfile("$tiff.txt") || '';
}
#--------------------------------------------------------------------------------------------
sub solve
{
    my ($self, $ocr, $file_path) = @_;
    my $text;
    eval {
        $text = $self->_get_ocr($ocr, $file_path);
    };
    if ($@)
    {
        $ocr->log->msg('OCR_ERROR', $@, 'DECODE CAPTCHA', 'red');
        return undef;
    }
    chomp $text;
    return $text;

}

sub report_bad { }

1;
