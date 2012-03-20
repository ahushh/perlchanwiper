package PCW::Engine::Simple;

#------------------------------------------------------------------------------------------------
# Абстрактный класс, предоставляющий интерфейс для модов (mode)
#------------------------------------------------------------------------------------------------
use strict;
use utf8;
use autodie;
use Carp;

#------------------------------------------------------------------------------------------------
# Features
#------------------------------------------------------------------------------------------------
use feature qw(switch);

#------------------------------------------------------------------------------------------------
# Import utility packages
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
sub new($%)
{
    my ($class, %args) = @_;
    my $agents   = delete $args{agents};
    my $loglevel = delete $args{loglevel} || 1;
    my $verbose  = delete $args{verbose}  || 0;

    # TODO: check for errors in the chan-config file
    Carp::croak("Option 'agents' should be are set.")
        unless(@$agents);

    my $self  = { loglevel => $loglevel, verbose => $verbose, agents => $agents, %args };
    bless $self, $class;
}

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
sub _get_page_url($%)
{
    my ($self, %config) = @_;
    Carp::croak("Board is not set! at _get_page_url")
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

# $self, %args -> (string)
sub _get_thread_url($%)
{
    my ($self, %config) = @_;
    Carp::croak("Board and thread are not set!")
        unless($config{board} && $config{thread});

    return sprintf $self->{urls}{thread}, $config{board}, $config{thread};
}

#------------------------------------------------------------------------------------------------
# HTML
#------------------------------------------------------------------------------------------------
# $self, $html -> %posts
# %posts:
#  (integer) => (string)
sub get_all_replies($$)
{
    my ($self, $html) = @_;
    my $pattern = $self->{html}{replies_regexp};

    my %posts;
    while ($html =~ /$pattern/sg)
    {
        $posts{ $+{id} } = $+{post};
    }
    return %posts;
}

# $self, $html -> %posts
# %posts:
#  (integer) => (string)
sub get_all_threads($$)
{
    my ($self, $html) = @_;

    my $pattern = $self->{html}{threads_regexp};

    my %threads;
    while ($html =~ /$pattern/sg)
    # while ($html =~ /$pattern/mg)
    {
        $threads{ $+{id} } = $+{thread};
    }
    return %threads;
}

#-- TODO: реализовать для общего случая.
# $self, %cnf -> (boolean)
# %cnf:
#  (integer) => thread
#  (integer) => page
sub is_thread_on_page($%)
{
    my ($self, %config) = @_;
    Carp::croak("Пока что не сделано...");
}

#------------------------------------------------------------------------------------------------
# headers
#------------------------------------------------------------------------------------------------
sub _get_post_headers($%)
{
    my ($self, %config) = @_;
    Carp::croak("Board is not set! at _get_post_headers")
        unless($config{board});

    my $referer = ($config{thread} ? $self->_get_thread_url(%config) : $self->_get_page_url(%config));

    my %h = %{ $self->{headers}{post} };
    $h{Referer} = $referer;
    return \%h;
}

sub _get_captcha_headers($%)
{
    my ($self, %config) = @_;

    Carp::croak("Board is not set! at _get_post_headers")
        unless($config{board});

    my $referer = ($config{thread} ? $self->_get_thread_url(%config) : $self->_get_page_url(%config));

    my %h = %{ $self->{headers}{captcha} };
    $h{Referer} = $referer;
    return \%h;

}

sub _get_delete_headers($%)
{
    my ($self, %config) = @_;
    Carp::croak("Board is not set! at _get_delete_headers")
        unless($config{board});
    $self->_get_post_headers(%config);
}

sub _get_default_headers($%)
{
    my ($self, %config) = @_;
    my $h = \%{ $self->{headers}{default} };
    return $h;
}

#------------------------------------------------------------------------------------------------
# Content
#------------------------------------------------------------------------------------------------
sub _get_post_content($%)
{
    my ($self, %config) = @_;
    Carp::croak("Call a virtual method!");
}

sub _get_delete_content($%)
{
    my ($self, %config) = @_;
    Carp::croak("Call a virtual method!");
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
    Carp::croak("This method is abstract and cannot be called directly.");
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
    Carp::croak("This method is abstract and cannot be called directly.");
}

#------------------------------------------------------------------------------------------------
# POST
#------------------------------------------------------------------------------------------------
# $self, $response, $code, $task, $cnf -> $status_str
sub _check_post_result($$$$$)
{
    my ($self, $response, $code, $task, $cnf) = @_;

    for my $type (keys %{ $self->{response}{post} })
    {
        my $color;
        given ($type)
        {
            when (/critical_error|banned|net_error/) { $color = 'red'    }
            when (/flood|post_error|wrong_captcha/)  { $color = 'yellow' }
            when (/success/)                         { $color = 'green'  }
        }

        for (@{ $self->{response}{post}{$type} })
        {
            if ($response =~ /$_/ || $code =~ /$_/)
            {
                echo_proxy(1, $color, $task->{proxy}, 'POST',
                            sprintf("[%s](%d){%s}", uc($type), $code, ($self->{verbose} ? html2text($response) : $_)));
                return($type);
            }
        }
    }

    echo_proxy(1, 'yellow', $task->{proxy}, 'POST',
        sprintf("[%s](%d){%s}", 'UNKNOWN', $code, ($self->{verbose} ? html2text($response) : 'unknown error')));
    return('unknown');
}

# $self, $task, $cnf -> $status_str
sub post($$$$)
{
    my ($self, $task, $cnf) = @_;

    #-- POSTING
    my ($code, $response) =
        http_post($task->{proxy},   $self->_get_post_url(%{ $cnf->{post_cnf} }),
                  $task->{headers}, $task->{content});

    $response = encode('utf-8', $response); #-- Для корректной работы кириллицы и рэгэкспов

    return $self->_check_post_result($response, $code, $task, $cnf);
}

#------------------------------------------------------------------------------------------------
# DELETE
#------------------------------------------------------------------------------------------------
# $self, $response, $code, $task, $cnf -> $status_str
sub _check_delete_result($$$$$)
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
                            sprintf("[%s](%d){%s}", uc($type), $code, ($self->{verbose} ? html2text($response) : $_)));
                return($type);
            }
        }
    }
    echo_proxy(1, 'yellow', 'No. '. $task->{delete}, 'DELETE',
        sprintf("[%s](%d){%s}", 'UNKNOWN', $code, ($self->{verbose} ? html2text($response) : 'unknown error')));
    return('unknown');
}

# $self, $task, $cnf -> $status_str
sub delete($$$$)
{
    my ($self, $task, $cnf) = @_;

    #-- Set headers
    my $headers = HTTP::Headers->new(%{ $self->_get_delete_headers(%{ $task }) });
    $headers->user_agent(rand_set(set => $self->{agents}));

    #-- Make content
    my %content = %{ merge_hashes($self->_get_delete_content(%{ $task }), $self->{fields}{delete}) };

    #-- Send request
    my ($code, $response) = http_post($task->{proxy}, $self->_get_delete_url(%{ $task }), $headers, \%content);

    $response = encode('utf-8', $response); #-- Для корректной работы кириллицы и рэгэкспов

    return $self->_check_delete_result($response, $code, $task, $cnf); 
}

#------------------------------------------------------------------------------------------------
#----------------------------------------- BAN CHECK --------------------------------------------
#------------------------------------------------------------------------------------------------
# $self, $response, $code, $task, $cnf -> $status_str
sub _check_ban_result($$$$$)
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
                            sprintf("[%s](%d){%s}", uc($type), $code, ($self->{verbose} ? html2text($response) : $_)));
                return($type);
            }
        }
    }

    echo_proxy(1, 'yellow', $task->{proxy}, 'CHECK',
        sprintf("[%s](%d){%s}", 'UNKNOWN', $code, ($self->{verbose} ? html2text($response) : 'unknown error')));

    return('unknown');
}

# $self, $task, $cnf -> $status_str
sub ban_check($$$)
{
    my ($self, $task, $cnf) = @_;

    my $post_headers = HTTP::Headers->new(%{ $self->_get_post_headers(%{ $cnf->{post_cnf} }) });
    $post_headers->user_agent(rand_set(set => $self->{agents}));
    $task->{headers} = $post_headers;

    my %content = %{ merge_hashes( $self->_get_post_content(%{ $cnf->{post_cnf} }), $self->{fields}{post}) };
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
        $content{ $self->{fields}{post}{img} } = ( $file_path ? [$file_path] : undef );
        $task->{file_path} = $file_path;
    }
    elsif (!$cnf->{post_cnf}{thread}) #-- New thread
    {
        $content{ $self->{fields}{post}{nofile} } = 'on';
    }

    $task->{content} = \%content;

    #-- POSTING
    my ($code, $response) =
        http_post($task->{proxy},   $self->_get_post_url(%{ $cnf->{post_cnf} }),
                  $task->{headers}, $task->{content});

    $response = encode('utf-8', $response); #-- Для корректной работы кириллицы и рэгэкспов

    return $self->_check_ban_result($response, $code, $task, $cnf);

}

#------------------------------------------------------------------------------------------------
#----------------------------------  OTHER METHODS  ---------------------------------------------
#------------------------------------------------------------------------------------------------
# $self, $task, $cnf -> $response, $response, $headers, $status_line
sub get_page($$$)
{
    my ($self, $task, $cnf) = @_;
    #-- Set headers
    my $headers = HTTP::Headers->new(%{ $self->_get_default_headers() });
    $headers->user_agent(rand_set(set => $self->{agents}));
    #-- Send request
    my ($response, $response_headers, $status_line) =
        http_get($task->{proxy}, $self->_get_page_url(%$cnf), $headers);

    #$response = encode('utf-8', $response); #-- Для корректной работы кириллицы и рэгэкспов

    return $response, $response_headers, $status_line;
}

# $self, $task, $cnf -> $response, $response, $headers, $status_line
sub get_thread($$$)
{
    my ($self, $task, $cnf) = @_;
    #-- Set headers
    my $headers = HTTP::Headers->new(%{ $self->_get_default_headers() });
    $headers->user_agent(rand_set(set => $self->{agents}));
    #-- Send request
    my ($response, $response_headers, $status_line) =
        http_get($task->{proxy}, $self->_get_thread_url(%$cnf), $headers);

    # $response = encode('utf-8', $response); #-- Для корректной работы кириллицы и рэгэкспов

    return $response, $response_headers, $status_line;
}

1;
