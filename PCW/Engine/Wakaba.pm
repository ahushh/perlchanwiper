package PCW::Engine::Wakaba;
 
use strict;
use utf8;
use autodie;
use Carp;

use base 'PCW::Engine::SimpleAbstract';

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
sub get_post_url($$%)
{
    my ($self, %config) = @_;
    Carp::croak("Board is not set! at get_post_url")
        unless($config{board});
    return sprintf $self->{urls}{post}, $config{board};
}

sub get_delete_url($$%) 
{
    my ($self, %config) = @_;
    Carp::croak("Board is not set! at get_delete_url")
        unless($config{board});
    return sprintf $self->{urls}{delete}, $config{board};
}

sub get_captcha_url($$%) 
{
    my ($self, %config) = @_;
    Carp::croak("Board is not set! at get_captcha_url")
        unless($config{board});
    if ($config{thread})
    {
        return sprintf $self->{urls}{captcha}, $config{board}, "res$config{thread}", $config{thread};
    }
    else
    {
        return sprintf $self->{urls}{captcha}, $config{board}, 'mainpage', '?';
    }
}

#sub get_page_url($$%)
#{
#}

#sub get_thread_url($$%)
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

#sub thread_exists($%)
#{
    #my (%config) = @_;
    #Carp::croak("Html and thread parameters are not set!")
        #unless($config{html} && $config{thread});
         
    #my $pattern = "<span id=\"exlink_$config{thread}\">";
    #my $pattern = "<span id=\"exlink_$config{thread}\">";
    #return $config{html} =~ /$pattern/;
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
    my $email    = $config{email};
    my $name     = $config{name};
    my $subject  = $config{subject};
    my $password = $config{password};
    my $nofile   = $config{nofile};

    my $content = {
        'task'       => 'post',
        'name'       => '',
        'link'       => '',
        'gb2'        => 'board',
        'email'      => $email,
        'subject'    => $subject,
        'password'   => $password,
    };
    $content->{nofile} = $nofile
        if ($nofile);
         
    $content->{thread} = $thread
        if ($thread);
         
    return $content;
}

sub get_delete_content($$%)
{
    my ($self, %config) = @_;
    Carp::croak("Delete and password parameters are not set!")
        unless($config{delete} && $config{password});
         
    my $content = {
        task     => 'delete',
        password => $config{password},
        delete   => $config{delete},
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
    my $captcha_img;
    #-- A simple captcha
    if (my $captcha_url = $self->get_captcha_url(%{ $cnf->{post_cnf} }))
    {
        my ($response_headers, $status_line);
        my $cap_headers = HTTP::Headers->new(%{ $self->get_captcha_headers(%{ $cnf->{post_cnf} }) });
        ($captcha_img, $response_headers, $status_line) = http_get($task->{proxy}, $captcha_url, $cap_headers);
             
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
    }
    #-- The recaptcha
    elsif ($self->{recaptcha_key})
    {
        my @fields;
        ($captcha_img, @fields) = get_recaptcha($task->{proxy}, $self->{recaptcha_key});
        unless ($captcha_img)
        {
            echo_proxy(1, 'red', $task->{proxy}, 'CAPTCHA', '[ERROR]{something wrong with recaptcha obtaining}');
            return('banned');
        }
        echo_proxy(1, 'green', $task->{proxy}, 'CAPTCHA', '[SUCCESS]{ok..recaptcha obtaining went well}');
        $task->{content} = { @fields };
    }
    my $path_to_captcha = save_file($captcha_img, $self->{captcha_extension});
    $task->{path_to_captcha} = $path_to_captcha;

    my $headers = HTTP::Headers->new(%{ $self->get_post_headers(%{ $cnf->{post_cnf} }) });
    $headers->user_agent(rand_set(set => $self->{agents}));
    $task->{headers} = $headers;

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
sub prepare($$$$)
{
    my ($self, $task, $cnf) = @_;
     
    #-- Recognize captcha
    my %content = %{ merge_hashes( $self->get_post_content(%{ $cnf->{post_cnf} }), $self->{fields}{post}) };
    if ($task->{path_to_captcha})
    {
        my $captcha_text = captcha_recognizer($cnf->{captcha_decode}, $task->{path_to_captcha});
        echo_proxy(1, 'green', $task->{proxy}, 'PREPARE', "captcha was recognized: $captcha_text");
                 
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

    # TODO
    echo_proxy(1, 'green', $task->{proxy}, 'PREPARE', "данные формы созданы");
                 
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
 
#sub ban_check($$$$)
#{
#}
 
#------------------------------------------------------------------------------------------------
#----------------------------------  OTHER METHODS  ---------------------------------------------
#------------------------------------------------------------------------------------------------
#sub get_page($$$$)
#{
#}

#sub get_thread($$$$)
#{
#}
 
1;
