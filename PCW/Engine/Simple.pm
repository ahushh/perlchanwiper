package PCW::Engine::Simple;

#------------------------------------------------------------------------------------------------
# Частично реализованны методы для cамых простых и распространенных движков имиджборд
#------------------------------------------------------------------------------------------------
use v5.12;
use utf8;
use Carp;

#------------------------------------------------------------------------------------------------
# Import utility packages
#------------------------------------------------------------------------------------------------
use Data::Random qw/rand_set/;
use HTTP::Headers;

#------------------------------------------------------------------------------------------------
# Import internal PCW packages
#------------------------------------------------------------------------------------------------
use PCW::Core::Utils   qw/merge_hashes parse_cookies html2text save_file unrandomize get_recaptcha/;
use PCW::Core::Net     qw/http_get http_post/;
use PCW::Data::Images  qw/make_pic/;
use PCW::Data::Text    qw/make_text/;

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
    my $agents  = delete $args{agents}  || 'Mozilla/5.0 (Windows; I; Windows NT 5.1; ru; rv:1.9.2.13) Gecko/20100101 Firefox/4.0';
    my $log     = delete $args{log};
    my $verbose = delete $args{verbose} || 0;

    my $self  = { log => $log, verbose => $verbose, agents => $agents, %args };
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
        unless(defined $config{board});
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
    Carp::croak("Board and thread are not set! at _get_thread_url")
        unless(defined $config{board} and defined $config{thread});

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

# $self, %cnf -> (boolean)
# %cnf:
#  (integer) => thread
#  (integer) => page
#  (string)  => board
#  (string)  => proxy
sub is_thread_on_page($%)
{
    my ($self, %config) = @_;
    my $log  = $self->{log};
    my $task = { proxy => $config{proxy} };
    my $cnf  = { page  => $config{page}, board => $config{board} };

    $log->msg('DATA_SEEK', "Looking for $config{thread} thread on $config{page} page...");
    my ($page, undef, $status) = $self->get_page($task, $cnf);
    $log->msg('DATA_LOADED', "Page $config{page} downloaded: $status");
    my %threads = $self->get_all_threads($page);

    return grep { $_ == $config{thread} } keys(%threads);
}

#------------------------------------------------------------------------------------------------
# headers
#------------------------------------------------------------------------------------------------
sub _get_post_headers($%)
{
    my ($self, %config) = @_;
    Carp::croak("Board is not set! at _get_post_headers")
        unless(defined $config{board});

    my $referer = ($config{thread} ? $self->_get_thread_url(%config) : $self->_get_page_url(%config));

    my %h = %{ $self->{headers}{post} };
    $h{Referer} = $referer;
    return \%h;
}

sub _get_captcha_headers($%)
{
    my ($self, %config) = @_;

    Carp::croak("Board is not set! at _get_captcha_headers")
        unless(defined $config{board});

    my $referer = ($config{thread} ? $self->_get_thread_url(%config) : $self->_get_page_url(%config));

    my %h = %{ $self->{headers}{captcha} };
    $h{Referer} = $referer;
    return \%h;

}

sub _get_delete_headers($%)
{
    my ($self, %config) = @_;
    Carp::croak("Board is not set! at _get_delete_headers")
        unless(defined $config{board});
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
    Carp::croak("This method is abstract and cannot be called directly.");
}

sub _get_delete_content($%)
{
    Carp::croak("This method is abstract and cannot be called directly.");
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
#  (hash)                 -> post_cnf        - post_cnf с уже выбранными случайными значениями
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
#  (hash)                 -> post_cnf        - post_cnf с уже выбранными случайными значениями
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
    my $log = $self->{log};

    for my $type (keys %{ $self->{response}{post} })
    {
        my ($color, $loglvl);
        given ($type)
        {
            when (/critical_error|banned|net_error/) { $color = 'red'   ; $loglvl = 'ENGN_POST_ERR' }
            when (/flood|post_error|wrong_captcha/)  { $color = 'yellow'; $loglvl = 'ENGN_POST_ERR' }
            when (/success/)                         { $color = 'green' ; $loglvl = 'ENGN_POST'     }
        }

        for (@{ $self->{response}{post}{$type} })
        {
            if ($response =~ /$_/ || $code =~ /$_/)
            {
                $log->pretty_proxy($loglvl, $color, $task->{proxy}, 'POST',
                            sprintf("[%s](%d){%s}", uc($type), $code, ($self->{verbose} ? html2text($response) : $_)));
                #if ($response =~ /detect/i)
                #{
                    #use Data::Dumper;
                    # ??????
                    #utf8::decode $task->{content}{captcha};
                    #utf8::decode $task->{content}{message};
                    #$log->pretty_proxy('DEBUG', 'red', $task->{proxy}, 'DEBUG', Dumper($task->{content}));
                    #say Dumper($task->{content});
                #}
                return($type);
            }
        }
    }

    $log->pretty_proxy('ENGN_POST_ERR', 'yellow', $task->{proxy}, 'POST',
        sprintf("[%s](%d){%s}", 'UNKNOWN', $code, ($self->{verbose} ? html2text($response) : 'unknown error')));
    return('unknown');
}

# $self, $task, $cnf -> $status_str
sub post($$$$)
{
    my ($self, $task, $cnf) = @_;

    #-- POSTING
    my $response =
        http_post(proxy   => $task->{proxy}  , url     => $self->_get_post_url(%{ $cnf->{post_cnf} }),
                  headers => $task->{headers}, content => $task->{content});

    return $self->_check_post_result($response->{content}, $response->{code}, $task, $cnf);
}

#------------------------------------------------------------------------------------------------
# DELETE
#------------------------------------------------------------------------------------------------
# $self, $response, $code, $task, $cnf -> $status_str
sub _check_delete_result($$$$$)
{
    my ($self, $response, $code, $task, $cnf) = @_;
    my $log = $self->{log};

    for my $type (keys %{ $self->{response}{delete} })
    {
        my ($color, $loglvl);
        given ($type)
        {
            when (/error|wrong_password/) { $color = 'red'  ; $loglvl = 'ENGN_DELETE_ERR' }
            when (/success/)              { $color = 'green'; $loglvl = 'ENGN_DELETE'     }
        }

        for (@{ $self->{response}{delete}{$type} })
        {
            if ($response =~ /$_/ || $code =~ /$_/)
            {
                $log->pretty_proxy($loglvl, $color, $task->{proxy}, "DELETE $task->{delete}",
                            sprintf("[%s](%d){%s}", uc($type), $code, ($self->{verbose} ? html2text($response) : $_)));
                return($type);
            }
        }
    }
    $log->pretty_proxy('ENGN_DELETE_ERR', 'yellow', $task->{proxy}, "DELETE $task->{delete}",
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
    my $response = http_post(proxy   => $task->{proxy}, url     => $self->_get_delete_url(%{ $task }),
                             headers => $headers      , content => \%content);

    return $self->_check_delete_result($response->{content}, $response->{code}, $task, $cnf);
}

#------------------------------------------------------------------------------------------------
#----------------------------------------- BAN CHECK --------------------------------------------
#------------------------------------------------------------------------------------------------
# $self, $response, $code, $task, $cnf -> $status_str
sub _check_ban_result($$$$$)
{
    my ($self, $response, $code, $task, $cnf) = @_;
    my $log = $self->{log};

    for my $type (keys %{ $self->{response}{post} })
    {
        my ($color, $loglvl);
        given ($type)
        {
            when (/banned|critical_error|net_error/) { $color = 'red'  ; $loglvl = 'ENGN_CHECK_ERR' }
            default                                  { $color = 'green'; $loglvl = 'ENGN_CHECK'     }
        }
        for (@{ $self->{response}{post}{$type} })
        {
            if ($response =~ /$_/ || $code =~ /$_/)
            {
                $log->pretty_proxy($loglvl, $color, $task->{proxy}, 'CHECK',
                            sprintf("[%s](%d){%s}", uc($type), $code, ($self->{verbose} ? html2text($response) : $_)));
                return($type);
            }
        }
    }

    $log->pretty_proxy('ENGN_CHECK_ERR', 'yellow', $task->{proxy}, 'CHECK',
        sprintf("[%s](%d){%s}", 'UNKNOWN', $code, ($self->{verbose} ? html2text($response) : 'unknown error')));

    return('unknown');
}

# $self, $task, $cnf -> $status_str
sub ban_check($$$)
{
    my ($self, $task, $cnf) = @_;

    $task->{post_cnf} = unrandomize( $cnf->{post_cnf} );
    my $post_headers = HTTP::Headers->new(%{ $self->_get_post_headers(%{ $task->{post_cnf} }) });
    $post_headers->user_agent(rand_set(set => $self->{agents}));
    $task->{headers} = $post_headers;

    my %content = %{ merge_hashes( $self->_get_post_content(%{ $task->{post_cnf} }), $self->{fields}{post}) };
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
    elsif (!$task->{post_cnf}{thread}) #-- New thread
    {
        $content{ $self->{fields}{post}{nofile} } = 'on';
    }

    $task->{content} = \%content;

    #-- POSTING
    my $response =
        http_post(proxy   => $task->{proxy}  , url     => $self->_get_post_url(%{ $task->{post_cnf} }),
                  headers => $task->{headers}, content => $task->{content});

    return $self->_check_ban_result($response->{content}, $response->{code}, $task, $cnf);

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
    my $response =
        http_get(proxy => $task->{proxy}, url => $self->_get_page_url(%$cnf), headers => $headers);

    return $response->{content}, $response->{headers}, $response->{status};
}

# $self, $task, $cnf -> $response, $response, $headers, $status_line
sub get_thread($$$)
{
    my ($self, $task, $cnf) = @_;
    #-- Set headers
    my $headers = HTTP::Headers->new(%{ $self->_get_default_headers() });
    $headers->user_agent(rand_set(set => $self->{agents}));
    #-- Send request
    my $response = 
        http_get(proxy => $task->{proxy}, url => $self->_get_thread_url(%$cnf), headers => $headers);

    return $response->{content}, $response->{headers}, $response->{status};
}

1;
