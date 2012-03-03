use strict;
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
    #-- Используем аргументы как хранилищие id и путей капч.
    $captcha_decode->{$file_path} = $id;
     
    my $cap_text = $recognizer->recognize($id);
    return $cap_text;
}

sub abuse($$)
{
    my ($captcha_decode, $file_path) = @_;
    my $key = $captcha_decode->{key};
    my $id  = delete $captcha_decode->{$file_path};
    my $recognizer = WebService::Antigate->new("key" => $key);
    return $recognizer->abuse($id);
}

1;
