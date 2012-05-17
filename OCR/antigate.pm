use v5.12;
use utf8;
use Carp;
use WebService::Antigate;

sub decode_captcha($$)
{
    my ($captcha_decode, $file_path) = @_;

    my $opt = $captcha_decode->{opt};
    my $key = $captcha_decode->{key};
    $opt->{file} = $file_path;

    my $recognizer = WebService::Antigate->new(
                                               "key"      => $key,
                                               "attempts" => 15,
                                              );
    my $id = $recognizer->upload(%$opt);
    unless ($id)
    {
        warn "Couldn't upload a captcha: ", $recognizer->errno;
        return undef;
    }
    #-- Используем аргументы как хранилищие id и путей капч
    #-- для дальнейшего их использования в abuse()
    $captcha_decode->{$file_path} = $id;

    my $cap_text = $recognizer->recognize($id);
    unless ($cap_text)
    {
        warn "Error while recognizing a captcha: ", $recognizer->errno;
        return undef;
    }
    return $cap_text;
}

sub abuse($$)
{
    my ($captcha_decode, $file_path) = @_;
    my $key = $captcha_decode->{key};
    my $id  = delete $captcha_decode->{$file_path};
    unless ($id)
    {
        return undef;
    }
    my $recognizer = WebService::Antigate->new("key" => $key);
    return $recognizer->abuse($id);
}

1;
