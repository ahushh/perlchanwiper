package PCW::Engine::Sosaba;

use v5.12;
use utf8;
use Carp;

use base 'PCW::Engine::Wakaba';

#------------------------------------------------------------------------------------------------
# Importing utility packages
#------------------------------------------------------------------------------------------------
use Data::Random qw/rand_set/;
use HTTP::Headers;

#------------------------------------------------------------------------------------------------
# Import internal PCW packages
#------------------------------------------------------------------------------------------------
use PCW::Core::Utils    qw/merge_hashes parse_cookies html2text save_file unrandomize took get_yacaptcha/;
use PCW::Core::Captcha  qw/captcha_recognizer/;
use PCW::Core::Net      qw/http_get http_post/;
use PCW::Data::Images   qw/make_pic/;
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
# sub _get_captcha_url($$%)
# {
# }

# $self, %args -> (string)
#sub _get_page_url($$%)
#{
#}

# $self, %args -> (string)
#sub _get_thread_url($$%)
#{
#}

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
#sub get_all_threads($$%)
#{
#}

# $self, %cnf -> (boolean)
# %cnf:
#  (integer) => thread
#  (integer) => page
#  (string)  => proxy
#sub is_thread_on_page
#{
#}

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
sub _get_post_content($%)
{
    my ($self, %config) = @_;
    my $thread   = $config{thread};
    my $email    = $config{email};
    my $name     = $config{name};
    my $subject  = $config{subject};
    my $video    = $config{video};

    my $content = {
        task          => 'роst',
        name          => '',
        akane         => $name,
        link          => '',
        email         => $email,
        subject       => $subject,
        submit        => 'Отправить',
        makewatermark => '',
        video         => $video  || '',
        thread        => $thread || '',
    };
    return $content;
}

# sub _get_delete_content($%)
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
sub get($$$$)
{
    my ($self, $task, $cnf) = @_;
    my $log = $self->{log};

    my $captcha_img;
    $task->{post_cnf} = unrandomize( $cnf->{post_cnf} );
    if (my $captcha_url = $self->_get_captcha_url(%{ $task->{post_cnf} }))
    {
        my $cap_headers = HTTP::Headers->new(%{ $self->_get_captcha_headers(%{ $task->{post_cnf} }) });
        my $response    = http_get(proxy => $task->{proxy}, url => $captcha_url, headers => $cap_headers);
        if (not defined $response or $response->{content} != /CHECK/)
        {
            $log->pretty_proxy('ENGN_GET_CAP', 'red', $task->{proxy}, 'GET', sprintf "[ERROR]{%s}", html2text($response->{status}));
            return('banned');
        }

        my $key      = (split /\n/, $response->{content})[1];
        $response    = get_yacaptcha($task->{proxy}, $key);
        $captcha_img = $response->decoded_content;

        if ($response->code != 200 or !$captcha_img or $captcha_img !~ /GIF|PNG|JFIF|JPEG|JPEH|JPG/i)
        {
            $log->pretty_proxy('ENGN_GET_CAP', 'red', $task->{proxy}, 'GET', sprintf "[ERROR]{%s}", $response->status_line);
            return('banned');
        }
        else
        {
            $log->pretty_proxy('ENGN_GET_ERR_CAP', 'green', $task->{proxy}, 'GET', "[SUCCESS]{$response->{status}}");
        }

        $task->{content} = { captcha => $key };
    }
    my $path_to_captcha = save_file($captcha_img, $self->{captcha_extension});
    $task->{path_to_captcha} = $path_to_captcha;

    my $headers = HTTP::Headers->new(%{ $self->_get_post_headers(%{ $task->{post_cnf} }) });
    $headers->user_agent(rand_set(set => $self->{agents}));
    $task->{headers} = $headers;

    return('success');
}
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
sub prepare($$$$)
{
    my ($self, $task, $cnf) = @_;
    my $log = $self->{log};

    #-- Recognize captcha
    my %content = %{ merge_hashes( $self->_get_post_content(%{ $task->{post_cnf} }), $self->{fields}{post}) };
    if ($task->{path_to_captcha})
    {
        my $took;
        my $captcha_text = took { captcha_recognizer($self->{ocr}, $log, $cnf->{captcha_decode}, $task->{path_to_captcha}) } \$took;
        unless (defined $captcha_text)
        {
            #-- an error has occured while recognizing captcha
            $log->pretty_proxy('ENGN_PRP_ERR_CAP', 'red', $task->{proxy}, 'PREPARE', "captcha recognizer returned undef (took $took sec.)");
            return('error');
        }
        unless ($captcha_text or $captcha_text =~ s/\s//gr)
        {
            $log->pretty_proxy('ENGN_PRP_ERR_CAP', 'red', $task->{proxy}, 'PREPARE', "captcha recognizer returned an empty string (took $took sec.)");
            return('no_text');
        }

        $log->pretty_proxy('ENGN_PRP_CAP', 'green', $task->{proxy}, 'PREPARE', "solved captcha: $captcha_text (took $took sec.)");
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
    #-- Image
    if ($cnf->{img_data}{mode} ne 'no')
    {
        my $file_path = make_pic( $self, $task, $cnf->{img_data} );
        $content{ $self->{fields}{post}{img} } = ( $file_path ? [$file_path] : undef );
        $task->{file_path} = $file_path;
    }

    if ($task->{content})
    {
        $task->{content} = { %{ $task->{content} },  %content };
    }
    else
    {
        $task->{content} = \%content;
    }

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
sub delete($$$$)
{
    Carp::croak('Mochan has no POST DELETION');
}

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

1;
