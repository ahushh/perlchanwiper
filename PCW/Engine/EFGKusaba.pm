package PCW::Engine::EFGKusaba;
 
use strict;
use utf8;
use autodie;
use Carp;

use base 'PCW::Engine::Kusaba';

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
#sub new($%)
#{
#}
#------------------------------------------------------------------------------------------------
# URL 
#------------------------------------------------------------------------------------------------
# sub get_post_url($$%)
# {
# }

# sub get_delete_url($$%) 
# {
# }

sub get_captcha_url($$%)
{
    my ($self, %config) = @_;
    return $self->{urls}{captcha} . "?" . rand;
}
#sub get_page_url($$%)

#sub get_page_url($$%)
#{
#}

#sub get_thread_url($$%)
#{
#}

#sub get_catalog_url($$%
#{
#}

#------------------------------------------------------------------------------------------------
# HTML 
#------------------------------------------------------------------------------------------------
#sub get_all_replies($$%)
#{
#} 

#sub get_all_threads($$%)
#{
#}

#sub thread_on_page
#{
#}

#------------------------------------------------------------------------------------------------
# headers
#------------------------------------------------------------------------------------------------
#sub get_post_headers($%)
#{
#}

#sub get_delete_headers($%)
#{
#}

#sub get_default_headers($%)
#{
#}
#------------------------------------------------------------------------------------------------
# Content
#------------------------------------------------------------------------------------------------
sub get_post_content($$%)
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
    $content->{nofile} = $nofile
        if ($nofile);
    return $content;
}

sub get_delete_content($$%)
{
    my ($self, %config) = @_;
    Carp::croak("Delete, board and password parameters are not set!")
        unless($config{board} && $config{password});

    my $deletestr = 'Удалить';
    utf8::encode($deletestr);
    my $content = {
        board    => $config{board},
        password => $config{password},
        delete   => $config{delete},
        deletepost => $deletestr,
    };
    return $content;
}

#------------------------------------------------------------------------------------------------
#----------------------------- CREATE POST, DELETE POST -----------------------------------------
#------------------------------------------------------------------------------------------------
#-- Create a new post on the board:
# 1. GET     (included captcha, cookies, headers and so on)
# 2. PREPARE (create post-form data, recognize captcha, do another stuff)
# 3. POST    (send request to server)
# 4. ???
# 5. PROFIT!

#------------------------------------------------------------------------------------------------
# GET
#------------------------------------------------------------------------------------------------
# task contains:
# proxy           - proxy address
# content         - content, который был получен при скачивании капчи
# path_to_captcha - no comments
# headers         - HTTP::Headers object
sub get($$$$)
{
    my ($self, $task, $cnf) = @_;
    my $post_headers = HTTP::Headers->new(%{ $self->get_post_headers(%{ $cnf->{post_cnf} }) });
    $post_headers->user_agent(rand_set(set => $self->{agents}));

    #-- Get captcha
    my $captcha_url = $self->get_captcha_url(%{ $cnf->{post_cnf} });
    my $cap_headers = HTTP::Headers->new(%{ $self->get_captcha_headers(%{ $cnf->{post_cnf} }) });
    my ($captcha_img, $response_headers, $status_line) = http_get($task->{proxy}, $captcha_url, $cap_headers);

    #-- Check result
    if ($status_line !~ /200/ or !$captcha_img or $captcha_img !~ /GIF|PNG|JFIF|JPEG|JPEH|JPG/)
    {
        echo_proxy(1, 'red', $task->{proxy}, 'CAPTCHA', sprintf "[ERROR]{%s}", html2text($status_line));
        return('banned');
    }
    else
    {
        echo_proxy(1, 'green', $task->{proxy}, 'CAPTCHA', "[SUCCESS]{$status_line}");
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

    #-- Save captcha
    my $path_to_captcha = save_file($captcha_img, $self->{captcha_extension});
    $task->{path_to_captcha} = $path_to_captcha;

    $task->{headers} = $post_headers;
    return('success');
}

#------------------------------------------------------------------------------------------------
# PREPARE
#------------------------------------------------------------------------------------------------
# task contains:
# proxy           - proxy address
# content         - content, который был получен при скачивании капчи
# path_to_captcha - no comments
# headers         - HTTP::Headers object
#########
# captcha_text    - recognized text
# file_path       - путь до файла, который отправляется на сервер
sub compute_mm($)
{
    my $s = shift;
    `lib/mm '$s'`;
}

sub prepare($$$$)
{
    my ($self, $task, $cnf) = @_;

    #-- Recognize captcha
    my %content = %{ merge_hashes( $self->get_post_content(%{ $cnf->{post_cnf} }), $self->{fields}{post}) };
    if ($task->{path_to_captcha})
    {
        my $captcha_text = captcha_recognizer($cnf->{captcha_decode}, $task->{path_to_captcha});
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

    #-- Compute mm cookie
    #use Data::Dumper;
    if ($content{board} eq 'b')
    {
        my $mm = compute_mm($content{mm} . $content{message} . $content{postpassword});
        #echo_msg($self->{loglevel} >= 4, "mm value: $mm");

        my $h  = $task->{headers};
        my $c = $h->header('Cookie');
        $c =~ s/; $//;
        #-- Add mm to post headers
        $h->header('Cookie' => "$c; mm=$mm");
        #echo_msg($self->{loglevel} >= 4, "$c; mm=$mm");
        # print Dumper($h);
    }

    echo_proxy(1, 'green', $task->{proxy}, 'PREPARE', "form data was created");
    $task->{content} = \%content;

    return('success');
}


#------------------------------------------------------------------------------------------------
# POST
#------------------------------------------------------------------------------------------------
#sub check_post_result($$$$$)
#{
#}

#sub post($$$$)
#{
#}
 
#------------------------------------------------------------------------------------------------
# DELETE
#------------------------------------------------------------------------------------------------
#sub check_delete_result($$$$$)
#{
#}
 
#sub delete($$$$)
#{
#}
 
#------------------------------------------------------------------------------------------------
#----------------------------------------- BAN CHECK --------------------------------------------
#------------------------------------------------------------------------------------------------
#sub ban_check_result($$$$$)
#{
#}
 
#sub ban_check($$$)
#{
#}
 
#------------------------------------------------------------------------------------------------
#----------------------------------  OTHER METHODS  ---------------------------------------------
#------------------------------------------------------------------------------------------------
#sub get_page($$$)
#{
#}

#sub get_thread($$$)
#{
#}

#sub get_catalog($$$)
#{
#}

1;
