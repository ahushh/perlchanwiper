use v5.12;
use utf8;
use Carp;
use WebService::Antigate;

sub decode_captcha($$$)
{
    my ($log, $captcha_decode, $file_path) = @_;
    my $opt = $captcha_decode->{opt};
    my $key = $captcha_decode->{key};
    $opt->{file} = $file_path;

    my $recognizer = WebService::Antigate->new(
                                               "key"      => $key,
                                               "attempts" => 15,
                                              );

    #$log->msg('MODE_STATE', sprintf("balance: %f", $recognizer->balance()));
    my $id = $recognizer->upload(%$opt);
    unless (defined $id)
    {
        $log->msg('OCR_ERROR', "Couldn't upload a captcha ($WebService::Antigate::DOMAIN): ". $recognizer->errno, 'DECODE CAPTCHA', 'red');
        return undef;
    }
    #-- Используем аргументы как хранилищие id и путей капч
    #-- для дальнейшего их использования в abuse()
    $captcha_decode->{$file_path} = $id;

    my $cap_text = $recognizer->recognize($id);
    unless (defined $cap_text)
    {
        $log->msg('OCR_ERROR', "Error while recognizing a captcha ($WebService::Antigate::DOMAIN): ". $recognizer->errno, 'DECODE CAPTCHA', 'red');
        return undef;
    }
    return $cap_text;
}

sub abuse($$$)
{
    my ($log, $captcha_decode, $file_path) = @_;
    my $key = $captcha_decode->{key};
    my $id  = delete $captcha_decode->{$file_path};
    my $recognizer = WebService::Antigate->new("key" => $key);
    if ($recognizer->abuse($id))
    {
        $log->msg('OCR_ABUSE_SUCCESS' , "Abuse to $id captcha was sent successfuly ($WebService::Antigate::DOMAIN)", 'ABUSE CAPTCHA', 'green');
    }
    else
    {
        $log->msg('OCR_ABUSE_ERROR', "Error while sending an abuse to $id captcha ($WebService::Antigate::DOMAIN): ". $recognizer->errno, 'ABUSE CAPTCHA', 'red');
    }
}

1;
