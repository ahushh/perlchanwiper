package PCW::Engine::Kusaba;

use v5.12;
use utf8;
use Carp;

use base 'PCW::Engine::Simple';

#------------------------------------------------------------------------------------------------
# Importing utility packages
#------------------------------------------------------------------------------------------------
use Data::Random qw/rand_set/;
use HTTP::Headers;

#------------------------------------------------------------------------------------------------
# Import internal PCW packages
#------------------------------------------------------------------------------------------------
use PCW::Core::Utils    qw/merge_hashes parse_cookies html2text save_file unrandomize took get_recaptcha/;
use PCW::Core::Captcha  qw/captcha_recognizer/;
use PCW::Core::Net      qw/http_get/;
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
sub _get_catalog_url($%)
{
    my ($self, %config) = @_;
    Carp::croak("Board is not set! at _get_catalog_url")
            unless(defined $config{board});

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

# $self, %cnf -> (boolean)
# %cnf:
#  (integer) => thread
#  (integer) => page
#  (string)  => board
#  (string)  => proxy
sub _is_thread_on_page_catalog($%)
{
    my ($self, %cnf) = @_;
    my $log = $self->{log};

    my $pattern = $self->{html}{catalog_regexp};
    my $task    = { proxy => $cnf{proxy} };
    my $c_cnf   = { board => $cnf{board} };
    $log->msg('DATA_SEEK', "Looking for $cnf{thread} thread on the catalog...");
    my ($html, undef, $status) = $self->get_catalog($task, $c_cnf);
    $log->msg('DATA_LOADING', "Catalog was downloaded: $status");

    my (%threads, $count);
    while ($html =~ /$pattern/sg)
    {
        $threads{ $count++ } = $+{id};
    }

    my $n    = $self->{threads_per_page};
    my $from = $cnf{page} * $n;
    my $to   = $from + $n;

    for ($from..$to)
    {
        return $_ if ($threads{$_} and $cnf{thread} eq $threads{$_});
    }
    return undef;
}
# $self, %cnf -> (boolean)
# %cnf:
#  (integer) => thread
#  (integer) => page
#  (string)  => board
#  (string)  => proxy
sub is_thread_on_page($%)
{
    my ($self, %cnf) = @_;
    if ($self->{urls}{catalog})
    {
        $self->_is_thread_on_page_catalog(%cnf);
    }
    else
    {
        PCW::Engine::Simple::is_thread_on_page($self, %cnf);
    }
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
        MAX_FILE_SIZE => 10240000,
        email         => $email,
        subject       => $subject,
        password      => $password,
        thread        => $thread,
        board         => $board,
    };
    $content->{nofile} = $nofile if $nofile;
    return $content;
}

sub _get_delete_content($$%)
{
    my ($self, %config) = @_;
    Carp::croak("Delete, board and password parameters are not set! at _get_delete_content")
        unless(defined $config{board} and defined $config{password});

    my $content = {
        board      => $config{board},
        password   => $config{password},
        delete     => $config{delete},
        deletepost => $config{deletepost},
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
#  (hash)                 -> post_cnf        - post_cnf с уже выбранными случайными значениями
sub get($$$$)
{
    my ($self, $task, $cnf) = @_;
    my $log = $self->{log};

    $task->{post_cnf} = unrandomize( $cnf->{post_cnf} );

    my $post_headers = HTTP::Headers->new(%{ $self->_get_post_headers(%{ $task->{post_cnf} }) });
    $post_headers->user_agent(rand_set(set => $self->{agents}));

    my $captcha_img;
    #-- A simple captcha
    if (my $captcha_url = $self->_get_captcha_url(%{ $task->{post_cnf} }))
    {
        my $cap_headers = HTTP::Headers->new(%{ $self->_get_captcha_headers(%{ $task->{post_cnf} }) });
        my $response    = http_get(proxy => $task->{proxy}, url => $captcha_url, headers => $cap_headers);
        $captcha_img    = $response->{content};

        #-- Check result
        if ($response->{status} !~ /200/ or !$captcha_img or $captcha_img !~ /GIF|PNG|JFIF|JPEG|JPEH|JPG/i)
        {
            $log->pretty_proxy('ENGN_GET_ERR_CAP', 'red', $task->{proxy}, 'GET', sprintf "[ERROR]{%s}", html2text($response->{status}));
            return('banned');
        }
        else
        {
            $log->pretty_proxy('ENGN_GET_CAP', 'green', $task->{proxy}, 'GET', "[SUCCESS]{$response->{status}}");
        }
        #-- Obtaining cookies
        if ($self->{cookies})
        {
            my $saved_cookies = parse_cookies($self->{cookies}, $response->{headers});
            if (!$saved_cookies)
            {
                $log->pretty_proxy('ENGN_GET_ERR_CAP', 'red', $task->{proxy}, 'GET', '[ERROR]{no cookies}');
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
            $log->pretty_proxy('ENGN_GET_ERR_CAP', 'red', $task->{proxy}, 'GET', '[ERROR]{something wrong with recaptcha obtaining}');
            return('banned');
        }
        $log->pretty_proxy('ENGN_GET_CAP', 'green', $task->{proxy}, 'GET', '[SUCCESS]{ok..recaptcha obtaining went well}');
        $task->{content} = { @fields };
    }
    my $path_to_captcha = save_file($captcha_img, $self->{captcha_extension});
    $task->{path_to_captcha} = $path_to_captcha;

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
#  (hash)                 -> post_cnf        - post_cnf с уже выбранными случайными значениями
#  (HTTP::Headers object) -> headers
#  (string)               -> captcha_text    - recognized text
#  (string)               -> file_path       - путь до файла, который отправляется на сервер
sub prepare($$$$)
{
    my ($self, $task, $cnf) = @_;
    my $log = $self->{log};

    #-- Recognize a captcha
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
        #-- Даже если постить картинки, а не видео, нужно указывать embedtype
        $content{ $self->{fields}{post}{video_type} } = $cnf->{vid_data}{type} || 'youtube';
        $content{ $self->{fields}{post}{video} }      = '';
    }
    elsif (!$cnf->{task}{thread} && $self->{fields}{post}{nofile}) #-- New thread
    {
        $content{ $self->{fields}{post}{nofile} } = 'on';
    }

    $task->{content} = { ($task->{content} ? %{$task->{content}} : ()), %content };

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
# $self, $task, $cnf -> $response, $response $headers, $status_line
#sub get_page($$$)
#{
#}

# $self, $task, $cnf -> $response, $response $headers, $status_line
#sub get_thread($$$)
#{
#}

# $self, $task, $cnf -> $response, $response $headers, $status_line
sub get_catalog($$$)
{
    my ($self, $task, $cnf) = @_;
    #-- Set headers
    my $headers = HTTP::Headers->new(%{ $self->_get_default_headers() });
    $headers->user_agent(rand_set(set => $self->{agents}));
    #-- Send request
    my $response =
        http_get(proxy => $task->{proxy}, url => $self->_get_catalog_url(%$cnf), headers => $headers);

    return $response->{content}, $response->{headers}, $response->{status};
}

1;
