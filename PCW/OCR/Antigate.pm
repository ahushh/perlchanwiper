package PCW::OCR::Hand;

use v5.12;
use Moo;
use utf8;
use Carp;
use WebService::Antigate;

has 'IDs' => (
    is => 'rw',
    default => sub { {} },
);

sub solve
{
    my ($self, $ocr, $file_path) = @_;
    my $opt = $ocr->config->{opt};
    my $key = $ocr->config->{key};
    $opt->{file} = $file_path;

    my $recognizer = WebService::Antigate->new(
                                               "key"      => $key,
                                               "attempts" => 15,
                                              );

    #$log->msg('MODE_STATE', sprintf("balance: %f", $recognizer->balance()));
    my $id;
    eval { $id = $recognizer->upload(%$opt); };
    if ($@)
    {
        $self->log->msg('OCR_ERROR', "Couldn't upload a captcha ($WebService::Antigate::DOMAIN): ". $@, 'DECODE CAPTCHA', 'red');
        return undef;
    }
    elsif (not defined $id)
    {
        $self->log->msg('OCR_ERROR', "Couldn't upload a captcha ($WebService::Antigate::DOMAIN): ". $recognizer->errno, 'DECODE CAPTCHA', 'red');
        return undef;
    }
    $ocr->IDs->{$file_path} = $id;

    my $cap_text = $recognizer->recognize($id);
    unless (defined $cap_text)
    {
        $self->log->msg('OCR_ERROR', "Error while recognizing a captcha ($WebService::Antigate::DOMAIN): ". $recognizer->errno, 'DECODE CAPTCHA', 'red');
        return undef;
    }
    return $cap_text;

}

sub report_bad
{
    my ($self, $ocr, $file_path) = @_;
    my $key = $captcha_decode->{key};
    my $id  = delete $ocr->IDs->{$file_path};
    my $recognizer = WebService::Antigate->new("key" => $key);
    if ($recognizer->abuse($id))
    {
        $log->msg('OCR_ABUSE_SUCCESS' , "$id captcha successfuly abused ($WebService::Antigate::DOMAIN)", 'ABUSE CAPTCHA', 'green');
    }
    else
    {
        $log->msg('OCR_ABUSE_ERROR', "Error while abusing $id captcha ($WebService::Antigate::DOMAIN): ". $recognizer->errno, 'ABUSE CAPTCHA', 'red');
    }
}

1;
