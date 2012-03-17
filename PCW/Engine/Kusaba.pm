package PCW::Engine::Kusaba;

use strict;
use utf8;
use autodie;
use Carp;

use base 'PCW::Engine::Simple';

#------------------------------------------------------------------------------------------------
# Features
#------------------------------------------------------------------------------------------------
use feature qw(switch); 

#------------------------------------------------------------------------------------------------
# Importing utility packages
#------------------------------------------------------------------------------------------------
use Data::Random qw(rand_set);
use Encode;
use File::Basename;
use HTTP::Headers;

#------------------------------------------------------------------------------------------------
# Import internal PCW packages
#------------------------------------------------------------------------------------------------
use PCW::Core::Utils    qw(merge_hashes parse_cookies html2text save_file);
use PCW::Core::Captcha  qw(captcha_recognizer);
use PCW::Core::Net      qw(http_get http_post get_recaptcha);
use PCW::Core::Log      qw(echo_msg echo_proxy);
use PCW::Data::Images   qw(make_pic);
use PCW::Data::Text     qw(make_text);

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
sub _get_post_url($%)
{
    my ($self, %config) = @_;
    return $self->{urls}{post};
}

# $self, %args -> (string)
sub _get_delete_url($%)
{
    my ($self, %config) = @_;
    return $self->{urls}{delete};
}

# $self, %args -> (string)
sub _get_captcha_url($%)
{
    my ($self, %config) = @_;
    return $self->{urls}{captcha};
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
sub get_catalog_url($%)
{
    my ($self, %config) = @_;
    Carp::croak("Board is not set!")
            unless($config{board});

    return sprintf $self->{urls}{catalog}, $config{board};
}

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

#-- TODO:
#-- Вызывать отсюда get_catalog_url/_get_thread_url, get_catalog/get_thread
#-- потому что реализация будет неизвестна.
sub is_thread_on_page
{
    my ($self, $html, $page, $thread) = @_;

    my $pattern = $self->{html}{catalog_regexp};

    my (%threads, $count);
    while ($html =~ /$pattern/sg)
    # while ($html =~ /$pattern/mg)
    {
        $threads{ $count++ } = $+{id};
    }

    my $n    = $self->{threads_per_page};
    my $from = ($page + 1) * $n;
    my $to   = $from + $n;
    for ($from..$to)
    {
        return $_ if ($thread eq $threads{$_});
    }
    return undef;
}

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
        'email'      => $email,
        'subject'    => $subject,
        'password'   => $password,
        'thread'     => $thread,
        'board'      => $board,
    };
    $content->{nofile} = $nofile
        if ($nofile);
    return $content;
}

sub _get_delete_content($$%)
{
    my ($self, %config) = @_;
    Carp::croak("Delete, board and password parameters are not set!")
        unless($config{board} && $config{password});

    my $content = {
        board    => $config{board},
        password => $config{password},
        delete   => $config{delete},
        deletepost => 'Удалить',
    };
    return $content;
}

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
#  (HTTP::Headers object) -> headers
sub get($$$$)
{
    my ($self, $task, $cnf) = @_;
    my $post_headers = HTTP::Headers->new(%{ $self->_get_post_headers(%{ $cnf->{post_cnf} }) });
    $post_headers->user_agent(rand_set(set => $self->{agents}));

    my $captcha_img;
    #-- A simple captcha
    if (my $captcha_url = $self->_get_captcha_url(%{ $cnf->{post_cnf} }))
    {
        my ($response_headers, $status_line);
        my $cap_headers = HTTP::Headers->new(%{ $self->_get_captcha_headers(%{ $cnf->{post_cnf} }) });
        ($captcha_img, $response_headers, $status_line) = http_get($task->{proxy}, $captcha_url, $cap_headers);

        #-- Check result
        if ($status_line !~ /200/ or !$captcha_img or $captcha_img !~ /GIF|PNG|JFIF|JPEG|JPEH|JPG/)
        {
            echo_proxy(1, 'red', $task->{proxy}, 'GET', sprintf "[ERROR]{%s}", html2text($status_line));
            return('banned');
        }
        else
        {
            echo_proxy(1, 'green', $task->{proxy}, 'GET', "[SUCCESS]{$status_line}");
        }
        #-- Obtaining cookies
        if ($self->{cookies})
        {
            my $saved_cookies = parse_cookies($self->{cookies}, $response_headers);
            if (!$saved_cookies)
            {
                echo_proxy(1, 'red', $task->{proxy}, 'COOKIES', '[ERROR]{required cookies not found/proxy does not supported cookies at all}');
                return('banned');
            }
            else
            {
                $post_headers->header('Cookie' => $saved_cookies);
            }
        }
    }
    #-- The recaptcha
    elsif ($self->{recaptcha_key})
    {
        my @fields;
        ($captcha_img, @fields) = get_recaptcha($task->{proxy}, $self->{recaptcha_key});
        unless ($captcha_img)
        {
            echo_proxy(1, 'red', $task->{proxy}, 'GET', '[ERROR]{something wrong with recaptcha obtaining}');
            return('banned');
        }
        echo_proxy(1, 'green', $task->{proxy}, 'GET', '[SUCCESS]{ok..recaptcha obtaining went well}');
        $task->{content} = { @fields };
    }
    if ($captcha_img)
    {
        my $path_to_captcha = save_file($captcha_img, $self->{captcha_extension});
        $task->{path_to_captcha} = $path_to_captcha;
    }

    $task->{headers} = $post_headers;

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
#  (HTTP::Headers object) -> headers
#  (string)               -> captcha_text    - recognized text
#  (string)               -> file_path       - путь до файла, который отправляется на сервер
sub prepare($$$$)
{
    my ($self, $task, $cnf) = @_;

    #-- Recognize captcha
    my %content = %{ merge_hashes( $self->_get_post_content(%{ $cnf->{post_cnf} }), $self->{fields}{post}) };
    if ($task->{path_to_captcha})
    {
        my $captcha_text = captcha_recognizer($cnf->{captcha_decode}, $task->{path_to_captcha});
        unless ($captcha_text)
        {
            echo_proxy(1, 'red', $task->{proxy}, 'PREPARE', "captcha recognizer returns undef.");
            return('error');
        }

        echo_proxy(1, 'green', $task->{proxy}, 'PREPARE', "solved captcha: $captcha_text");
        $content{ $self->{fields}{post}{captcha} } = $captcha_text;
        $task->{captcha_text}                      = $captcha_text;
    }

    #---- Form data
    #-- Message
    if ($cnf->{msg_data}{mode} ne 'no')
    {
        my $text = make_text( $cnf->{msg_data} );
        $content{ $self->{fields}{post}{msg} } = $text;
    }
    #-- Image
    if ($cnf->{img_data}{mode} ne 'no')
    {
        my $file_path = make_pic( $cnf->{img_data} );
        $content{ $self->{fields}{post}{img} } = ( $file_path ? [$file_path] : undef);
        $task->{file_path} = $file_path;
    }
    elsif (!$cnf->{post_cnf}{thread}) #-- New thread
    {
        $content{ $self->{fields}{post}{nofile} } = 'on';
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
sub get_catalog($$$)
{
    my ($self, $task, $cnf) = @_;
    #-- Set headers
    my $headers = HTTP::Headers->new(%{ $self->_get_default_headers() });
    $headers->user_agent(rand_set(set => $self->{agents}));
    #-- Send request
    my ($response, $response_headers, $status_line) =
        http_get($task->{proxy}, $self->get_catalog_url(%$cnf), $headers);

    # $response = encode('utf-8', $response); #-- Для корректной работы кириллицы и рэгэкспов

    return $response, $response_headers, $status_line;
}

1;
