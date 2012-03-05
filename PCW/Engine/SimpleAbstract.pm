package PCW::Engine::SimpleAbstract;
 
#------------------------------------------------------------------------------------------------
# Виртуальный класс для простых движков (wakaba, tinyib, kusaba etc.)
#------------------------------------------------------------------------------------------------
 
use strict;
use utf8;
use autodie;
use Carp;

#------------------------------------------------------------------------------------------------
# Package Variables
#------------------------------------------------------------------------------------------------
our $LOGLEVEL;
our $VERBOSE;
 
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
sub new($%)
{
    my ($class, %args) = @_;
    my $agents   = delete $args{agents};
    my $loglevel = delete $args{loglevel};
    my $verbose  = delete $args{verbose};
     
    $LOGLEVEL = $loglevel || 0;
    $VERBOSE  = $verbose  || 0;

    # TODO: check for errors in the chan-config file
    Carp::croak("Option 'agents' should be are set.")
        unless(@$agents);
     
    my $self  = { agents => $agents, %args };
    bless $self, $class;
}
 
#------------------------------------------------------------------------------------------------
# URL 
#------------------------------------------------------------------------------------------------
sub get_post_url($$%)
{
    my ($self, %config) = @_;
    return $self->{urls}{post};
}

sub get_delete_url($$%) 
{
    my ($self, %config) = @_;
    return $self->{urls}{delete};
}

sub get_captcha_url($$%) 
{
    my ($self, %config) = @_;
    return $self->{urls}{captcha};
}

sub get_page_url($$%)
{
    my ($self, %config) = @_;
    Carp::croak("Board is not set! at get_page_url")
        unless($config{board});
    if ($config{page})
    {
        return sprintf $self->{urls}{page}, $config{board}, $config{page};
    }
    else
    {
        return sprintf $self->{urls}{zero_page}, $config{board};
    }
}

sub get_thread_url($$%)
{
    my ($self, %config) = @_;
    Carp::croak("Board and thread are not set!")
        unless($config{board} && $config{thread});

    return sprintf $self->{urls}{thread}, $config{board}, $config{thread};
}

#------------------------------------------------------------------------------------------------
# HTML 
#------------------------------------------------------------------------------------------------
sub get_all_replies($$%)
{
    my ($self, %config) = @_;
    Carp::croak("Html parameter is not set!")
        unless($config{html});

    my $pattern = $self->{html}{replies_regexp};
     
    my %posts;
    while ($config{html} =~ /$pattern/mg)
    {
        $posts{ $+{id} } = $+{post};
    }
    return %posts;
} 

sub get_all_threads($$%)
{
    my ($self, %config) = @_;
    Carp::croak("Html parameter is not set!")
        unless($config{html});
     
    my $pattern = $self->{html}{threads_regexp};
     
    my %threads;
    while ($config{html} =~ /$pattern/mg)
    {
        $threads{ $+{id} } = $+{thread};
    }
    return %threads;
}

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
sub get_post_headers($%)
{
    my ($self, %config) = @_;
    Carp::croak("Board is not set! at get_post_headers")
        unless($config{board});

    my $referer = ($config{thread} ? $self->get_thread_url(%config) : $self->get_page_url(%config));

    my %h = %{ $self->{headers}{post} };
    $h{Referer} = $referer;
    return \%h;
}

sub get_delete_headers($%)
{
    my ($self, %config) = @_;
    Carp::croak("Board is not set! at get_delete_headers")
        unless($config{board});
    $self->get_post_headers(%config);
}

sub get_default_headers($%)
{
    my ($self, %config) = @_;
    my $h = \%{ $self->{headers}{default} };
    return $h;
}
#------------------------------------------------------------------------------------------------
# Content
#------------------------------------------------------------------------------------------------
#-- Virtual
sub get_post_content($$%)
{
    my ($self, %config) = @_;
    Carp::croak("Calling virtual method!");
}

#-- Virtual
sub get_delete_content($$%)
{
    my ($self, %config) = @_;
     
    Carp::croak("Calling virtual method!");
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
#------------------------------------------------------------------------------------------------
#-- Virtual
sub get($$$$)
{
    Carp::croak("Calling virtual method!");
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
#------------------------------------------------------------------------------------------------
#-- Virtual
sub prepare($$$$)
{
    Carp::croak("Calling virtual method!");
}
     
 
#------------------------------------------------------------------------------------------------
# POST
#------------------------------------------------------------------------------------------------
sub check_post_result($$$$$)
{
    my ($self, $response, $code, $task, $cnf) = @_;
     
    for my $type (keys %{ $self->{response}{post} })
    {
        my $color;
        given ($type)
        {
            when (/critical_error|banned|net_error|wrong_captcha/) { $color = 'red'    }
            when (/flood|file_exist|bad_file/)                     { $color = 'yellow' }
            when (/success/)                                       { $color = 'green'  }
        }
         
        for (@{ $self->{response}{post}{$type} })
        {
            if ($response =~ /$_/ || $code =~ /$_/)
            {
                echo_proxy(1, $color, $task->{proxy}, 'POST',
                            sprintf("[%s](%d){%s}", uc($type), $code, ($VERBOSE ? html2text($response) : $_)));
                return($type);
            }
        }
    }
     
    echo_proxy(1, 'yellow', $task->{proxy}, 'POST',
        sprintf("[%s](%d){%s}", 'UNKNOWN', $code, ($VERBOSE ? html2text($response) : 'unknown error')));
    return('unknown');
}

sub post($$$$)
{
    my ($self, $task, $cnf) = @_;
     
    #-- POSTING
    my ($code, $response) =
        http_post($task->{proxy},   $self->get_post_url(%{ $cnf->{post_cnf} }),
                  $task->{headers}, $task->{content});
         
    $response = encode('utf-8', $response); #-- Для корректной работы кириллицы и рэгэкспов

    return $self->check_post_result($response, $code, $task, $cnf);
}
 
#------------------------------------------------------------------------------------------------
# DELETE
#------------------------------------------------------------------------------------------------
sub check_delete_result($$$$$)
{
    my ($self, $response, $code, $task, $cnf) = @_;
     
    for my $type (keys %{ $self->{response}{delete} })
    {
        my $color;
        given ($type)
        {
            when (/error/)   { $color = 'red'    }
            when (/success/) { $color = 'green'  }
        }
         
        for (@{ $self->{response}{delete}{$type} })
        {
            if ($response =~ /$_/ || $code =~ /$_/)
            {
                echo_proxy(1, $color, 'No. '. $task->{delete}, 'DELETE',
                            sprintf("[%s](%d){%s}", uc($type), $code, ($VERBOSE ? html2text($response) : $_)));
                return($type);
            }
        }
    }
    echo_proxy(1, 'yellow', 'No. '. $task->{delete}, 'DELETE',
        sprintf("[%s](%d){%s}", 'UNKNOWN', $code, ($VERBOSE ? html2text($response) : 'unknown error')));
    return('unknown');
}
 
sub delete($$$$)
{
    my ($self, $task, $cnf) = @_;
     
    #-- Set headers
    my $headers = HTTP::Headers->new(%{ $self->get_delete_headers(%{ $task }) });
    $headers->user_agent(rand_set(set => $self->{agents}));
    
    #-- Make content
    my %content = %{ merge_hashes($self->get_delete_content(%{ $task }), $self->{fields}{delete}) };

    #-- Send request
    my ($code, $response) = http_post($task->{proxy}, $self->get_delete_url(%{ $task }), $headers, \%content);
 
    $response = encode('utf-8', $response); #-- Для корректной работы кириллицы и рэгэкспов
     
    return $self->check_delete_result($response, $code, $task, $cnf); 
}
 
#------------------------------------------------------------------------------------------------
#----------------------------------------- BAN CHECK --------------------------------------------
#------------------------------------------------------------------------------------------------
sub ban_check_result($$$$$)
{
    my ($self, $response, $code, $task, $cnf) = @_;
     
    for my $type (keys %{ $self->{response}{post} })
    {
        my $color;
        given ($type)
        {
            when (/banned|critical_error|net_error/) { $color = 'red'   }
            default                                  { $color = 'green' }
        }
         
        for (@{ $self->{response}{post}{$type} })
        {
            if ($response =~ /$_/ || $code =~ /$_/)
            {
                echo_proxy(1, $color, $task->{proxy}, 'CHECK',
                            sprintf("[%s](%d){%s}", uc($type), $code, ($VERBOSE ? html2text($response) : $_)));
                return($type);
            }
        }
    }
     
    echo_proxy(1, 'yellow', $task->{proxy}, 'CHECK',
        sprintf("[%s](%d){%s}", 'UNKNOWN', $code, ($VERBOSE ? html2text($response) : 'unknown error')));
    return('unknown');
}
 
sub ban_check($$$$)
{
    my ($self, $task, $cnf) = @_;
     
    my %content = %{ merge_hashes( $self->get_post_content(%{ $cnf->{post_cnf} }), $self->{fields}{post}) };
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
     
    $task->{content} = \%content;
     
    #-- POSTING
    my ($code, $response) =
        http_post($task->{proxy},   $self->get_post_url(%{ $cnf->{post_cnf} }),
                  $task->{headers}, $task->{content});
         
    $response = encode('utf-8', $response); #-- Для корректной работы кириллицы и рэгэкспов

    return $self->ban_check_result($response, $code, $task, $cnf);
}
 
#------------------------------------------------------------------------------------------------
#----------------------------------  OTHER METHODS  ---------------------------------------------
#------------------------------------------------------------------------------------------------
sub get_page($$$$)
{
    my ($self, $task, $cnf) = @_;
    #-- Set headers
    my $headers = HTTP::Headers->new(%{ $self->get_default_headers() });
    $headers->user_agent(rand_set(set => $self->{agents}));
    #-- Send request
    my ($response, $response_headers, $status_line) =
        http_get($task->{proxy}, $self->get_page_url(%$cnf), $headers);
         
    $response = encode('utf-8', $response); #-- Для корректной работы кириллицы и рэгэкспов
     
    return $response, $response_headers, $status_line;
}

sub get_thread($$$$)
{
    my ($self, $task, $cnf) = @_;
    #-- Set headers
    my $headers = HTTP::Headers->new(%{ $self->get_default_headers() });
    $headers->user_agent(rand_set(set => $self->{agents}));
    #-- Send request
    my ($response, $response_headers, $status_line) =
        http_get($task->{proxy}, $self->get_thread_url(%$cnf), $headers);
         
    $response = encode('utf-8', $response); #-- Для корректной работы кириллицы и рэгэкспов
     
    return $response, $response_headers, $status_line;
}
 
1;
