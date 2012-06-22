package PCW::Engine::EFGKusaba;

use v5.12;
use utf8;
use Carp;

use base 'PCW::Engine::Kusaba';

#------------------------------------------------------------------------------------------------
# Importing utility packages
#------------------------------------------------------------------------------------------------
use Data::Random qw/rand_set/;
use FindBin      qw/$Bin/;
use HTTP::Headers;

#------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------
use JE;
our $js = JE->new;
$js->eval('
function mm(a)
{
    var l = a.length,
        h = 2 ^ l,
        i = 0,
        k, m = 1540483477,
        ff = 255,
        ffff = 65535;
    while (l >= 4) {
        k = ((a.charCodeAt(i) & ff)) | ((a.charCodeAt(++i) & ff) << 8) | ((a.charCodeAt(++i) & ff) << 16) | ((a.charCodeAt(++i) & ff) << 24);
        k = (((k & ffff) * m) + ((((k >>> 16) * m) & ffff) << 16));
        k ^= k >>> 24;
        k = (((k & ffff) * m) + ((((k >>> 16) * m) & ffff) << 16));
        h = (((h & ffff) * m) + ((((h >>> 16) * m) & ffff) << 16)) ^ k;
        l -= 4;
        ++i
    }
    switch (l) {
        case 3:
            h ^= (a.charCodeAt(i + 2) & ff) << 16;
        case 2:
            h ^= (a.charCodeAt(i + 1) & ff) << 8;
        case 1:
            h ^= (a.charCodeAt(i) & ff);
            h = (((h & ffff) * m) + ((((h >>> 16) * m) & ffff) << 16))
    }
    h ^= h >>> 13;
    h = (((h & ffff) * m) + ((((h >>> 16) * m) & ffff) << 16));
    h ^= h >>> 15;
    var c = h >>> 0;
    return c;
}');

#------------------------------------------------------------------------------------------------
# Import internal PCW packages
#------------------------------------------------------------------------------------------------
use PCW::Core::Utils    qw/merge_hashes parse_cookies html2text save_file unrandomize took/;
use PCW::Core::Captcha  qw/captcha_recognizer/;
use PCW::Core::Net      qw/http_get http_post get_recaptcha/;
use PCW::Data::Images   qw/make_pic/;
use PCW::Data::Video    qw/make_vid/;
use PCW::Data::Text     qw/make_text/;

#------------------------------------------------------------------------------------------------
# Constructor
#------------------------------------------------------------------------------------------------
# $classname, %config -> classname object
# %config:
#  (list of strings) => agents
#  (integer)         => loglevel
#  (boolean)         => verbose
#sub new($%)
#{
#}

#------------------------------------------------------------------------------------------------
#----------------------------------  PRIVATE METHODS  -------------------------------------------
#------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------
# URL
#------------------------------------------------------------------------------------------------
# $self, %args -> (string)
# sub _get_post_url($%)
# {
# }

# $self, %args -> (string)
# sub _get_delete_url($%)
# {
# }

# $self, %args -> (string)
sub _get_captcha_url($$%)
{
    my ($self, %config) = @_;
    return $self->{urls}{captcha} . "?" . rand;
}

# $self, %args -> (string)
#sub _get_page_url($%)
#{
#}

# $self, %args -> (string)
#sub _get_thread_url($%)
#{
#}

# $self, %args -> (string)
# sub _get_catalog_url($%)
# {
# }

#------------------------------------------------------------------------------------------------
# HTML
#------------------------------------------------------------------------------------------------
# $self, $html -> %posts
# %posts:
#  (integer) => (string)
#sub get_all_replies($$%)
#{
#}

# $self, $html -> %posts
# %posts:
#  (integer) => (string)
#sub get_all_threads($$%)
#{
#}

# $self, %cnf -> (boolean)
# %cnf:
#  (integer) => thread
#  (integer) => page
#  (string)  => board
#  (string)  => proxy
# sub is_thread_on_page($%)
# {
# }

#------------------------------------------------------------------------------------------------
# headers
#------------------------------------------------------------------------------------------------
#sub _get_post_headers($%)
#{
#}

#sub _get_delete_headers($%)
#{
#}

#sub _get_default_headers($%)
#{
#}
#------------------------------------------------------------------------------------------------
# Content
#------------------------------------------------------------------------------------------------
sub _get_post_content($$%)
{
    my ($self, %config) = @_;
    my $thread   = $config{thread};
    my $board    = $config{board};
    my $email    = $config{email};
    my $name     = $config{name};
    my $subject  = $config{subject};
    my $password = $config{password};
    my $nofile   = $config{nofile};

    my $content = {
                   'MAX_FILE_SIZE' => 10240000,
                   'email'         => $email,
                   'subject'       => $subject,
                   'password'      => $password,
                   'thread'        => $thread,
                   'board'         => $board,
                   'mm'            => 0,
                  };
    $content->{nofile} = $nofile if $nofile;
    return $content;
}

# sub _get_delete_content($$%)
# {
# }

#------------------------------------------------------------------------------------------------
#----------------------------- CREATE POST, DELETE POST -----------------------------------------
#------------------------------------------------------------------------------------------------
#-- Create a new post on the board:
# 1. GET     (included fetching captcha, cookies, headers and so on)
# 2. PREPARE (create post-form data, recognize captcha, do another stuff)
# 3. POST    (send request to server)
# 4. ???
# 5. PROFIT!
#------------------------------------------------------------------------------------------------
# GET
#------------------------------------------------------------------------------------------------
# $self, $task, $cnf -> $status_str
# \%task:
#  (string)               -> proxy           - proxy address
#  (hash)                 -> content         - content, который был получен при скачивании капчи
#  (string)               -> path_to_captcha - путь до файла с капчой
#  (hash)                 -> post_cnf        - post_cnf с уже выбранными случайными значениями
#  (HTTP::Headers object) -> headers
# sub get($$$$)
# {
# }

#------------------------------------------------------------------------------------------------
# PREPARE
#------------------------------------------------------------------------------------------------
# $self, $task, $cnf -> $status_str
# \%task:
#  (string)               -> proxy           - proxy address
#  (hash)                 -> content         - content, который был получен при скачивании капчи
#  (string)               -> path_to_captcha - путь до файла с капчой
#  (hash)                 -> post_cnf        - post_cnf с уже выбранными случайными значениями
#  (HTTP::Headers object) -> headers
#  (string)               -> captcha_text    - recognized text
#  (string)               -> file_path       - путь до файла, который отправляется на сервер

#-- Helper function
sub compute_mm($)
{
    my $s = shift;
    #-- there are non-ascii characters or OS is not linux
    if ( grep { ord($_) > 127 } split //, $s or $^O !~ /linux/)
    {
        utf8::encode($s);
        return $js->method(mm => $s); #-- so sloooow
    }
    #-- ascii only
    open my $mm, '-|', "$Bin/lib/mm", $s
        or Carp::croak "Could not find $Bin/lib/mm: $!";
    my $result = <$mm>;
    close($mm);
    return $result;
}
 
sub prepare($$$$)
{
    my ($self, $task, $cnf) = @_;
    my $log = $self->{log};

    #-- Recognize a captcha
    my %content = %{ merge_hashes( $self->_get_post_content(%{ $task->{post_cnf} }), $self->{fields}{post}) };
    if ($task->{path_to_captcha})
    {
        my $took;
        my $captcha_text = took { captcha_recognizer($cnf->{captcha_decode}, $task->{path_to_captcha}) } \$took;
        unless ($captcha_text)
        {
            $log->pretty_proxy(1, 'red', $task->{proxy}, 'PREPARE', "captcha recognizer returned undef (took $took sec.)");
            return('no_captcha');
        }

        $log->pretty_proxy(1, 'green', $task->{proxy}, 'PREPARE', "solved captcha: $captcha_text (took $took sec.)");
        $content{ $self->{fields}{post}{captcha} } = $captcha_text;
        $task->{captcha_text}                      = $captcha_text;
    }

    #---- Form data
    #-- Message
    if ($cnf->{msg_data}{text})
    {
        my $text = make_text( $self, $task, $cnf->{msg_data} );
        $content{ $self->{fields}{post}{msg} } = $text;
    }
    #-- Image and video
    if ($cnf->{vid_data}{mode} ne 'no')
    {
        my $video_id = make_vid( $self, $task, $cnf->{vid_data} );
        $content{ $self->{fields}{post}{video}      } = $video_id;
        $content{ $self->{fields}{post}{video_type} } = $cnf->{vid_data}{type};
    }
    elsif ($cnf->{img_data}{mode} ne 'no')
    {
        my $file_path = make_pic( $self, $task, $cnf->{img_data} );
        $content{ $self->{fields}{post}{img} } = ( $file_path ? [$file_path] : undef );
        $task->{file_path} = $file_path;
    }
    elsif (!$task->{post_cnf}{thread}) #-- New thread
    {
        $content{ $self->{fields}{post}{nofile} } = 'on';
    }

    #-- Compute mm cookie
    if ($content{board} eq 'b')
    {
        my ($took, $mm);
        #-- if the text is empty or the text is staic, compute mm only once
        if (($cnf->{msg_data}{text} eq '' or $cnf->{msg_data}{text} !~ /#|%|@~/)
            and !$self->{static_mm})
        {
            $self->{static_mm} = took { compute_mm($content{mm} . $content{message} . $content{postpassword}) } \$took;
            $log->pretty_proxy(3, 'green', $task->{proxy}, 'PREPARE', "mm was computed: $self->{static_mm} (took $took sec.)");
        }
        if ($self->{static_mm})
        {
            $mm = $self->{static_mm};
        }
        else
        {
            $mm = took { compute_mm($content{mm} . $content{message} . $content{postpassword}) } \$took;
            $log->pretty_proxy(3, 'green', $task->{proxy}, 'PREPARE', "mm was computed: $mm (took $took sec.)");
        }
        #-- Add mm to post headers
        my $h = $task->{headers};
        my $c = $h->header('Cookie');
        $c =~ s/; $//;
        $h->header('Cookie' => "$c; mm=$mm");
    }

    $task->{content} = \%content;

    return('success');
}

#------------------------------------------------------------------------------------------------
# POST
#------------------------------------------------------------------------------------------------
# $self, $response, $code, $task, $cnf -> $status_str
#sub _check_post_result($$$$$)
#{
#}

# $self, $task, $cnf -> $status_str
#sub post($$$$)
#{
#}

#------------------------------------------------------------------------------------------------
# DELETE
#------------------------------------------------------------------------------------------------
# $self, $response, $code, $task, $cnf -> $status_str
#sub _check_delete_result($$$$$)
#{
#}

# $self, $response, $code, $task, $cnf -> $status_str# $self, $task, $cnf -> $status_str
#sub delete($$$$)
#{
#}

#------------------------------------------------------------------------------------------------
#----------------------------------------- BAN CHECK --------------------------------------------
#------------------------------------------------------------------------------------------------
# $self, $response, $code, $task, $cnf -> $status_str
#sub _check_ban_result($$$$$)
#{
#}

# $self, $task, $cnf -> $status_str
#sub ban_check($$$)
#{
#}

#------------------------------------------------------------------------------------------------
#----------------------------------  OTHER METHODS  ---------------------------------------------
#------------------------------------------------------------------------------------------------
# $self, $task, $cnf -> $response, $response, $headers, $status_line
#sub get_page($$$)
#{
#}

# $self, $task, $cnf -> $response, $response, $headers, $status_line
#sub get_thread($$$)
#{
#}

# $self, $task, $cnf -> $response, $response, $headers, $status_line
# sub get_catalog($$$)
# {
# }

1;
