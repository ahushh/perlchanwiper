package PCW::Engine::Wakaba;
 
use strict;
use utf8;
use autodie;
use Carp;

#------------------------------------------------------------------------------------------------
# Package Variables
#------------------------------------------------------------------------------------------------
our $DEBUG;
our $VERBOSE;
 
#------------------------------------------------------------------------------------------------
# Feature
#------------------------------------------------------------------------------------------------
use feature qw(switch); 
 
#------------------------------------------------------------------------------------------------
# Importing utility packages
#------------------------------------------------------------------------------------------------
use Data::Random qw(rand_set);
use Encode;
use File::Basename;
use File::Copy qw(move);
use HTTP::Headers;
 
#------------------------------------------------------------------------------------------------
# Importing internal PCW packages
#------------------------------------------------------------------------------------------------
use PCW::Utils          qw(merge_hashes parse_cookies html2text save_file);
use PCW::Captcha        qw(captcha_recognizer);
use PCW::Core::Net      qw(http_get http_post get_recaptcha);
use PCW::Core::Log      qw(echo_msg echo_msg_dbg echo_proxy echo_proxy_dbg);
use PCW::Data::Images   qw(make_pic);
use PCW::Data::Text     qw(make_text);
 
#------------------------------------------------------------------------------------------------
# Constructor
#------------------------------------------------------------------------------------------------
sub new($%)
{
    my ($class, %args) = @_;
    my $agents  = delete $args{agents};
    my $debug   = delete $args{debug};
    my $verbose = delete $args{verbose};
     
    $DEBUG   = $debug   || 0;
    $VERBOSE = $verbose || 0;

    Carp::croak("Option 'agents' should be are set.")
        unless(@$agents);
     
    my $self  = { agents => $agents };
    bless $self, $class;
}
 
#------------------------------------------------------------------------------------------------
# URL 
#------------------------------------------------------------------------------------------------
sub get_post_url($$%)
{
    my ($self, $chan, %config) = @_;
    Carp::croak("Board is not set! at get_post_url")
        unless($config{board});
    return sprintf $chan->{urls}{post}, $config{board};
}

sub get_delete_url($$%) 
{
    my ($self, $chan, %config) = @_;
    Carp::croak("Board is not set! at get_delete_url")
        unless($config{board});
    return sprintf $chan->{urls}{delete}, $config{board};
}

sub get_captcha_url($$%) 
{
    my ($self, $chan, %config) = @_;
    Carp::croak("Board is not set! at get_captcha_url")
        unless($config{board});
    if ($config{thread})
    {
        return sprintf $chan->{urls}{captcha}, $config{board}, "res$config{thread}", $config{thread};
    }
    else
    {
        return sprintf $chan->{urls}{captcha}, $config{board}, 'mainpage', '?';
    }
}

sub get_page_url($$%)
{
    my ($self, $chan, %config) = @_;
    Carp::croak("Board is not set! at get_page_url")
        unless($config{board});
    if ($config{page})
    {
        return sprintf $chan->{urls}{page}, $config{board}, $config{page};
    }
    else
    {
        return sprintf $chan->{urls}{zero_page}, $config{board};
    }
}

sub get_thread_url($$%)
{
    my ($self, $chan, %config) = @_;
    Carp::croak("Board and thread are not set!")
        unless($config{board} && $config{thread});

    return sprintf $chan->{urls}{thread}, $config{board}, $config{thread};
}

#------------------------------------------------------------------------------------------------
# HTML 
#------------------------------------------------------------------------------------------------
sub find_all_replies($$%)
{
    my ($self, $chan, %config) = @_;
    Carp::croak("Html parameter is not set!")
        unless($config{html});

    my $pattern = $chan->{html}{replies_regexp};
     
    my %posts;
    while ($config{html} =~ /$pattern/mg)
    {
        $posts{ $+{id} } = $+{post};
    }
    return %posts;
} 

sub find_all_threads($$%)
{
    my ($self, $chan, %config) = @_;
    Carp::croak("Html parameter is not set!")
        unless($config{html});
     
    my $pattern = $chan->{html}{threads_regexp};
     
    my %threads;
    while ($config{html} =~ /$pattern/mg)
    {
        $threads{ $+{id} } = $+{thread};
    }
    return %threads;
}

#sub thread_exists($%)
#{
    #my ($chan, %config) = @_;
    #Carp::croak("Html and thread parameters are not set!")
        #unless($config{html} && $config{thread});
         
    #my $pattern = "<span id=\"exlink_$config{thread}\">";
    #my $pattern = "<span id=\"exlink_$config{thread}\">";
    #return $config{html} =~ /$pattern/;
#}
 
#------------------------------------------------------------------------------------------------
# headers
#------------------------------------------------------------------------------------------------
sub get_post_headers($$%)
{
    my ($self, $chan, %config) = @_;
    Carp::croak("Board is not set! at get_post_headers")
        unless($config{board});

    my $referer = ($config{thread} ? get_thread_url($self, $chan, %config) : get_page_url($self, $chan, %config));

    my %h = %{ $chan->{headers}{post} };
    $h{Referer} = $referer;
    return \%h;
}

sub get_delete_headers($$%)
{
    my ($self, $chan, %config) = @_;
    Carp::croak("Board is not set! at get_delete_headers")
        unless($config{board});
    get_post_headers($self, $chan, %config);
}

sub get_default_headers($$%)
{
    my ($self, $chan, %config) = @_;
    my $h = \%{ $chan->{headers}{default} };
    return $h;
}
#------------------------------------------------------------------------------------------------
# Content
#------------------------------------------------------------------------------------------------
sub get_post_content($$%)
{
    my ($self, $chan, %config) = @_;
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
    my ($self, $chan, %config) = @_;
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
#------------------------------------ POST METHODS ----------------------------------------------
#------------------------------------------------------------------------------------------------

#------------------------------------------------------------------------------------------------
# GET
#------------------------------------------------------------------------------------------------
sub get($$$$)
{
    my ($self, $task, $chan, $cnf) = @_;
    my $headers = HTTP::Headers->new(%{ get_post_headers($self, $chan, %{ $cnf->{post_cnf} }) });
    $headers->user_agent(rand_set(set => $self->{agents}));
     
    #unless ($chan->get_captcha_url(%{ $cnf->{post_cnf} }) || $chan->{recaptcha_key} )
    #{
        #Carp::croak("Incorrect captcha options");
    #}
     
    my $captcha_img;
    #-- A simple captcha
    if (my $captcha_url = get_captcha_url($self, $chan, %{ $cnf->{post_cnf} }))
    {
        my ($response_headers, $status_line);
        ($captcha_img, $response_headers, $status_line) = http_get($task->{proxy}, $captcha_url, $headers);
             
        #-- Check result
        if ($status_line !~ /200/ or !$captcha_img or $captcha_img !~ /GIF|PNG|JFIF|JPEG|JPEH|JPG/)
        {
            echo_proxy('red', $task->{proxy}, 'CAPTCHA', sprintf "[ERROR]{%s}", html2text($status_line));
            return('banned');
        }
        else
        {
            echo_proxy('green', $task->{proxy}, 'CAPTCHA', "[SUCCESS]{$status_line}");
        }
         
        #-- Obtaining cookies
        #if ($chan->{cookies})
        #{
            #my $saved_cookies = parse_cookies($self, $chan->{cookies}, $response_headers);
            #if (!$saved_cookies)
            #{
                #echo_proxy('red', $task->{proxy}, 'COOKIES', '[ERROR]{required cookies not found/proxy does not supported cookies at all}');
                #return('banned');
            #}
            #else
            #{
                #$headers->header('Cookie' => $saved_cookies);
            #}
        #}
    }
    #-- The recaptcha
    elsif ($chan->{recaptcha_key})
    {
        my @fields;
        ($captcha_img, @fields) = get_recaptcha($task->{proxy}, $chan->{recaptcha_key});
        unless ($captcha_img)
        {
            echo_proxy('red', $task->{proxy}, 'CAPTCHA', '[ERROR]{something wrong with recaptcha obtaining}');
            return('banned');
        }
        echo_proxy('green', $task->{proxy}, 'CAPTCHA', '[SUCCESS]{ok..recaptcha obtaining went well}');
        $task->{content} = { @fields };
    }
    my $path_to_captcha = save_file($captcha_img, $chan->{captcha_extension});
    $task->{path_to_captcha} = $path_to_captcha;
     
    $task->{headers} = $headers;
    return('success');
}
 
     
#------------------------------------------------------------------------------------------------
# PREPARE
#------------------------------------------------------------------------------------------------
sub prepare($$$$)
{
    my ($self, $task, $chan, $cnf) = @_;
     
    #-- Recognize captcha
    my %content = %{ merge_hashes( get_post_content($self, $chan, %{ $cnf->{post_cnf} }), $chan->{fields}{post}) };
    if ($task->{path_to_captcha})
    {
        my $captcha_text = captcha_recognizer($cnf->{captcha_decode}, $task->{path_to_captcha});
        echo_proxy('green', $task->{proxy}, 'PREPARE', "captcha was recognized: $captcha_text");
                 
        $content{ $chan->{fields}{post}{captcha} } = $captcha_text;
    } 

    #---- Form data
    #-- Message
    if ($cnf->{msg_data}{mode} ne 'no')
    {
        my $text = make_text( $cnf->{msg_data} );
        $content{ $chan->{fields}{post}{msg} } = $text;
    }
    #-- Image
    if ($cnf->{img_data}{mode} ne 'no')
    {
        my $file_path = make_pic( $cnf->{img_data} );
        $content{ $chan->{fields}{post}{img} } = ( $file_path ? [$file_path] : undef);
        $task->{file_path} = $file_path;
    }
    elsif (!$cnf->{post_cnf}{thread}) #-- New thread
    {
        $content{ $chan->{fields}{post}{nofile} } = 'on';
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
# MAKE
#------------------------------------------------------------------------------------------------
sub check_post_result($$$$$)
{
    my ($response, $code, $task, $chan, $cnf) = @_;
     
    for my $type (keys %{ $chan->{response}{post} })
    {
        my $color;
        given ($type)
        {
            when (/banned|net_error|wrong_captcha/) { $color = 'red'    }
            when (/chan_error/)                     { $color = 'yellow' }
            when (/success/)                        { $color = 'green'  }
        }
         
        for (@{ $chan->{response}{post}{$type} })
        {
            if ($response =~ /$_/ || $code =~ /$_/)
            {
                echo_proxy($color, $task->{proxy}, 'POST',
                            sprintf("[%s](%d){%s}", uc($type), $code, ($VERBOSE ? html2text($response) : $_)));
                return($type);
            }
        }
    }
     
    echo_proxy('yellow', $task->{proxy}, 'POST',
        sprintf("[%s](%d){%s}", 'UNKNOWN', $code, ($VERBOSE ? html2text($response) : 'unknown error')));
    return('unknown');
}

sub post($$$$)
{
    my ($self, $task, $chan, $cnf) = @_;
     
    #-- POSTING
    my ($code, $response) =
        http_post($task->{proxy},   get_post_url($self, $chan, %{ $cnf->{post_cnf} }),
                  $task->{headers}, $task->{content});
         
    $response = encode('utf-8', $response); #-- Для корректной работы кириллицы и рэгэкспов

    return check_post_result($response, $code, $task, $chan, $cnf);
}
 
#------------------------------------------------------------------------------------------------
# PROXY CHECK
#------------------------------------------------------------------------------------------------
sub check_proxy_checker_result($$$$$)
{
    my ($response, $code, $task, $chan, $cnf) = @_;
     
    for my $type (keys %{ $chan->{response}{post} })
    {
        my $color;
        given ($type)
        {
            when (/banned/)                          { $color = 'red'   }
            when (/success|net_error|wrong_captcha/) { $color = 'green' }
        }
         
        for (@{ $chan->{response}{post}{$type} })
        {
            if ($response =~ /$_/ || $code =~ /$_/)
            {
                echo_proxy($color, $task->{proxy}, 'CHECK',
                            sprintf("[%s](%d){%s}", uc($type), $code, ($VERBOSE ? html2text($response) : $_)));
                return($type);
            }
        }
    }
     
    echo_proxy('yellow', $task->{proxy}, 'CHECK',
        sprintf("[%s](%d){%s}", 'UNKNOWN', $code, ($VERBOSE ? html2text($response) : 'unknown error')));
    return('unknown');
}
sub check_proxy($$$$)
{
    my ($self, $task, $chan, $cnf) = @_;
     
    my %content = %{ merge_hashes( get_post_content($self, $chan, %{ $cnf->{post_cnf} }), $chan->{fields}{post}) };
    #---- Form data
    #-- Message
    if ($cnf->{msg_data}{mode} ne 'no')
    {
        my $text = make_text( $cnf->{msg_data} );
        $content{ $chan->{fields}{post}{msg} } = $text;
    }
    #-- Image
    if ($cnf->{img_data}{mode} ne 'no')
    {
        my $file_path = make_pic( $cnf->{img_data} );
        $content{ $chan->{fields}{post}{img} } = ( $file_path ? [$file_path] : undef);
        $task->{file_path} = $file_path;
    }
    elsif (!$cnf->{post_cnf}{thread}) #-- New thread
    {
        $content{ $chan->{fields}{post}{nofile} } = 'on';
    }
     
    $task->{content} = \%content;
     
    #-- POSTING
    my ($code, $response) =
        http_post($task->{proxy},   get_post_url($self, $chan, %{ $cnf->{post_cnf} }),
                  $task->{headers}, $task->{content});
         
    $response = encode('utf-8', $response); #-- Для корректной работы кириллицы и рэгэкспов

    return check_proxy_checker_result($response, $code, $task, $chan, $cnf);
}
 
#------------------------------------------------------------------------------------------------
# DELETE
#------------------------------------------------------------------------------------------------
sub check_delete_result($$$$$)
{
    my ($response, $code, $task, $chan, $cnf) = @_;
     
    for my $type (keys %{ $chan->{response}{delete} })
    {
        my $color;
        given ($type)
        {
            when (/error/)   { $color = 'red'    }
            when (/success/) { $color = 'green'  }
        }
         
        for (@{ $chan->{response}{delete}{$type} })
        {
            if ($response =~ /$_/ || $code =~ /$_/)
            {
                echo_proxy($color, 'No. '. $task->{delete}, 'DELETE',
                            sprintf("[%s](%d){%s}", uc($type), $code, ($VERBOSE ? html2text($response) : $_)));
                return($type);
            }
        }
    }
    echo_proxy('yellow', 'No. '. $task->{delete}, 'DELETE',
        sprintf("[%s](%d){%s}", 'UNKNOWN', $code, ($VERBOSE ? html2text($response) : 'unknown error')));
    return('unknown');
}
 
sub delete($$$$)
{
    my ($self, $task, $chan, $cnf) = @_;
     
    #-- Set headers
    my $headers = HTTP::Headers->new(%{ get_delete_headers($self, $chan, %{ $task }) });
    $headers->user_agent(rand_set(set => $self->{agents}));
    
    #-- Make content
    my %content = %{ merge_hashes(get_delete_content($self, $chan, %{ $task }), $chan->{fields}{delete}) };

    #-- Send request
    my ($code, $response) = http_post($task->{proxy}, get_delete_url($self, $chan, %{ $task }), $headers, \%content);
 
    $response = encode('utf-8', $response); #-- Для корректной работы кириллицы и рэгэкспов
     
    return check_delete_result($response, $code, $task, $chan, $cnf); 
}
 
#------------------------------------------------------------------------------------------------
#----------------------------------  OTHER METHODS  ---------------------------------------------
#------------------------------------------------------------------------------------------------
sub get_page($$$$)
{
    my ($self, $task, $chan, $cnf) = @_;
    #-- Set headers
    my $headers = HTTP::Headers->new(%{ get_default_headers($self, $chan) });
    $headers->user_agent(rand_set(set => $self->{agents}));
    #-- Send request
    my ($response, $response_headers, $status_line) =
        http_get($task->{proxy}, get_page_url($self, $chan, %$cnf), $headers);
         
    $response = encode('utf-8', $response); #-- Для корректной работы кириллицы и рэгэкспов
     
    return $response, $response_headers, $status_line;
}

sub get_thread($$$$)
{
    my ($self, $task, $chan, $cnf) = @_;
    #-- Set headers
    my $headers = HTTP::Headers->new(%{ get_default_headers($self, $chan) });
    $headers->user_agent(rand_set(set => $self->{agents}));
    #-- Send request
    my ($response, $response_headers, $status_line) =
        http_get($task->{proxy}, get_thread_url($self, $chan, %$cnf), $headers);
         
    $response = encode('utf-8', $response); #-- Для корректной работы кириллицы и рэгэкспов
     
    return $response, $response_headers, $status_line;
}
 
1;
