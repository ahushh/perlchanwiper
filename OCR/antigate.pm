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
    my $id = $recognizer->upload(%$opt);
    unless (defined $id)
    {
        $log->msg(2, "Couldn't upload a captcha ($WebService::Antigate::DOMAIN): ". $recognizer->errno, 'DECODE CAPTCHA', 'red');
        return undef;
    }
    #-- Используем аргументы как хранилищие id и путей капч
    #-- для дальнейшего их использования в abuse()
    $captcha_decode->{$file_path} = $id;

    my $cap_text = $recognizer->recognize($id);
    unless (defined $cap_text)
    {
        $log->msg(2, "Error while recognizing a captcha ($WebService::Antigate::DOMAIN): ". $recognizer->errno, 'DECODE CAPTCHA', 'red');
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
    unless ($recognizer->abuse($id))
    {
        $log->msg(2, "Error while send an abuse on $id captcha ($WebService::Antigate::DOMAIN): ". $recognizer->errno, 'ABUSE CAPTCHA', 'red');
    }
    else
    {
        $log->msg(3, "Abuse on $id captcha was sended successfuly ($WebService::Antigate::DOMAIN)", 'ABUSE CAPTCHA', 'green');
    }
}

1;
