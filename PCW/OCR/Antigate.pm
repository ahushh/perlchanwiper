package PCW::OCR::Antigate;

use v5.12;
use Moo;
use utf8;
use Carp;

use File::Spec;
#use FindBin qw/$Bin/;
use lib File::Spec->catfile('.', 'lib');

use WebService::Antigate;

has 'IDs' => (
    is => 'rw',
    default => sub { {} },
);

sub solve
{
    my ($self, $ocr, $file_path) = @_;
    my %opt = %{ $ocr->config->{opt} };
    my $key = $ocr->config->{key};
    $opt{file} = $file_path;

    my $recognizer = WebService::Antigate->new(
                                               "key"      => $key,
                                               "attempts" => 15,
                                              );

    #$log->msg('MODE_STATE', sprintf("balance: %f", $recognizer->balance()));
    my $id;
    eval { $id = $recognizer->upload(%opt); };
    if ($@)
    {
        $ocr->log->msg('OCR_ERROR', "Couldn't upload a captcha ($WebService::Antigate::DOMAIN): ". $@, 'DECODE CAPTCHA', 'red');
        return undef;
    }
    elsif (not defined $id)
    {
        $ocr->log->msg('OCR_ERROR', "Couldn't upload a captcha ($WebService::Antigate::DOMAIN): ". $recognizer->errno, 'DECODE CAPTCHA', 'red');
        return undef;
    }
    $self->IDs->{$file_path} = $id;

    my $cap_text = $recognizer->recognize($id);
    unless (defined $cap_text)
    {
        $ocr->log->msg('OCR_ERROR', "Error while recognizing a captcha ($WebService::Antigate::DOMAIN): ". $recognizer->errno, 'DECODE CAPTCHA', 'red');
        return undef;
    }
    return $cap_text;
}

sub report_bad
{
    my ($self, $ocr, $file_path) = @_;
    unless ($self->IDs->{file_path} and $self->IDs->{file_path})
    {
        $ocr->log->msg('OCR_ABUSE_ERROR' , "nothing to report, no captcha has been uploaded ($WebService::Antigate::DOMAIN)", 'ABUSE CAPTCHA', 'yellow');
        return;
    }
    my $key = $ocr->config->{key};
    my $id  = delete $self->IDs->{$file_path};
    my $recognizer = WebService::Antigate->new("key" => $key);
    if ($recognizer->abuse($id))
    {
        $ocr->log->msg('OCR_ABUSE_SUCCESS' , "successfuly reported to captcha $id ($WebService::Antigate::DOMAIN)", 'ABUSE CAPTCHA', 'green');
    }
    else
    {
        $ocr->log->msg('OCR_ABUSE_ERROR', "Error while reporting to $id captcha ($WebService::Antigate::DOMAIN): ". $recognizer->errno, 'ABUSE CAPTCHA', 'red');
    }
}

1;
