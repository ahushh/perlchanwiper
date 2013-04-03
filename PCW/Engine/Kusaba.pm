package PCW::Engine::Kusaba;

#------------------------------------------------------------------------------------------------
use v5.12;
use Hash::Util "lock_keys";
use Moo;
use utf8;
use Carp qw/croak/;

extends 'PCW::Engine::Simple';

#------------------------------------------------------------------------------------------------
use Data::Random qw/rand_set/;
use HTTP::Headers;

use PCW::Core::Utils  qw/merge_hashes parse_cookies html2text save_file unrandomize took get_recaptcha/;
use PCW::Core::OCR    qw/captcha_recognizer/;
use PCW::Core::Net    qw/http_get/;
use PCW::Data::Images qw/make_pic/;
use PCW::Data::Video  qw/make_vid/;
use PCW::Data::Text   qw/make_text/;
#------------------------------------------------------------------------------------------------
#----------------------------------  PRIVATE METHODS  -------------------------------------------
#------------------------------------------------------------------------------------------------

#------------------------------------------------------------------------------------------------
# URL
#------------------------------------------------------------------------------------------------
#sub _get_url_post
#{
#}

#sub _get_url_delete
#{
#}

#sub _get_url_captcha
#{
#}

#sub _get_url_page
#{
#}

#sub _get_url_thread
#{
#}

#------------------------------------------------------------------------------------------------
# HTML
#------------------------------------------------------------------------------------------------
sub get_replies
{
    croak('TODO PARSE HTML');
}

sub get_threads
{
    croak('TODO PARSE HTML');
}

sub is_thread_on_page
{
    croak('TODO PARSE HTML');
}

#------------------------------------------------------------------------------------------------
# headers
#------------------------------------------------------------------------------------------------
#sub _get_headers_post
#{
#}

#sub _get_headers_captcha
#{
#}

#sub _get_headers_delete
#{
#}

#sub _get_headers_default
#{
#}

#------------------------------------------------------------------------------------------------
# Content
#------------------------------------------------------------------------------------------------
sub _get_fields_post
{
    my ($self, $fields) = @_;
    my $thread   = $fields->{thread};
    my $board    = $fields->{board};
    my $email    = $fields->{email};
    my $name     = $fields->{name};
    my $subject  = $fields->{subject};
    my $password = $fields->{password};
    my $nofile   = $fields->{nofile};

    my $content = {
        MAX_FILE_SIZE  => 10240000,
        _email         => $email,
        _subject       => $subject,
        _password      => $password,
        _thread        => $thread,
        _board         => $board,
    };
    $content->{nofile} = $nofile if $nofile;
    return $content;
}

sub _get_fields_delete
{
    my ($self, $fields) = @_;
    my $content = {
        board      => $fields->{board},
        password   => $fields->{password},
        delete     => $fields->{delete},
        deletepost => $fields->{deletepost},
    };
    return $content;
}

#------------------------------------------------------------------------------------------------
#--------------------------------------- MAIN METHODS -------------------------------------------
#------------------------------------------------------------------------------------------------

#------------------------------------------------------------------------------------------------
sub get_captcha
{
    my ($self, $task, $post_fields) = @_;

    $task->{post_fields} = unrandomize( $post_fields );

    my $post_headers = HTTP::Headers->new(%{ $self->_get_headers_post( $task->{post_fields} ) });
    $post_headers->user_agent(rand_set(set => $self->agents));

    my $captcha_img;
    #-- A plain captcha
    if (my $captcha_url = $self->_get_url_captcha( $task->{post_fields} ))
    {
        my $cap_headers = HTTP::Headers->new(%{ $self->_get_headers_captcha( $task->{post_fields} ) });
        my $took;
        my $response    = took { http_get(proxy => $task->{proxy}, url => $captcha_url, headers => $cap_headers) } \$took;
        $captcha_img    = $response->{content};

        #-- Check result
        if ($response->{status} !~ /200/ or !$captcha_img or $captcha_img !~ /GIF|PNG|JFIF|JPEG|JPEH|JPG/i)
        {
            $self->log->pretty_proxy('ENGINE_GET_CAPTCHA_ERROR', 'red', $task->{proxy}, 'GET CAPTCHA', sprintf "[ERROR]{%s} (took $took sec.)", html2text($response->{status}));
            return('banned');
        }
        else
        {
            $self->log->pretty_proxy('ENGINE_GET_CAPTCHA', 'green', $task->{proxy}, 'GET CAPTCHA', "[SUCCESS]{$response->{status}} (took $took sec.)");
        }
        #-- Obtaining cookies
        if ($self->chan_config->{captcha_cookies})
        {
            my $saved_cookies = parse_cookies($self->chan_config->{captcha_cookies}, $response->{headers});
            if (!$saved_cookies)
            {
                $self->log->pretty_proxy('ENGINE_GET_CAPTCHA_ERROR', 'red', $task->{proxy}, 'GET CAPTCHA', '[ERROR]{no cookies} (took $took sec.)');
                return('banned');
            }
            else
            {
                $post_headers->header('Cookie' => $saved_cookies);
            }
        }
    }
    #-- The recaptcha
    elsif ($self->chan_config->{recaptcha_key})
    {
        my (@fields, $took);
        ($captcha_img, @fields) = took { get_recaptcha($task->{proxy}, $self->chan_config->{recaptcha_key}) } \$took;
        unless ($captcha_img)
        {
            $self->log->pretty_proxy('ENGINE_GET_CAPTCHA_ERROR', 'red', $task->{proxy}, 'GET CAPTCHA', '[ERROR]{something wrong with recaptcha obtaining} (took $took sec.)');
            return('banned');
        }
        $self->log->pretty_proxy('ENGINE_GET_CAPTCHA', 'green', $task->{proxy}, 'GET CAPTCHA', '[SUCCESS]{ok..recaptcha obtaining went well} (took $took sec.)');
        $task->{content} = { @fields };
    }
    my $path_to_captcha = save_file($captcha_img, $self->chan_config->{captcha_extension});
    $task->{path_to_captcha} = $path_to_captcha;

    $task->{headers} = $post_headers;
    return('success');
}

#------------------------------------------------------------------------------------------------
#sub handle_captcha
#{
#}

#------------------------------------------------------------------------------------------------
sub prepare_data
{
    my ($self, $task, undef) = @_;

    if (defined $self->common_config->{message}{text})
    {
        my $text = $self->data->text->fetch( $self, $task, $self->common_config->{message} );
        $task->{content}{ $self->chan_config->{fields}{post}{_message} } = $text;
    }
    if (defined $self->common_config->{video}{mode})
    {
        my $video_id = $self->data->video->fetch( $self, $task, $self->common_config->{video} );
        $task->{content}{ $self->chan_config->{fields}{post}{_video}      } = $video_id;
        $task->{content}{ $self->chan_config->{fields}{post}{_video_type} } = $self->common_config->{video}{type};
    }
    elsif (defined $self->common_config->{image}{mode})
    {
        my $file_path = $self->data->image->fetch( $self, $task, $self->common_config->{image} );
        $task->{content}{ $self->chan_config->{fields}{post}{_image} } = ( $file_path ? [$file_path] : undef );
        $task->{file_path} = $file_path;
        $task->{content}{ $self->chan_config->{fields}{post}{_video_type} } = $self->common_config->{video}{type} || 'youtube';
        $task->{content}{ $self->chan_config->{fields}{post}{_video} }      = '';
    }
    elsif (!$self->common_config->{task}{thread} && $self->chan_config->{fields}{post}{nofile}) #-- New thread
    {
        $task->{content}{ $self->chan_config->{fields}{post}{nofile} } = 'on';
    }

    return('success');
}

#------------------------------------------------------------------------------------------------
#sub _check_post_result
#{
#}

#sub make_post
#{
#}

#------------------------------------------------------------------------------------------------
# DELETE
#------------------------------------------------------------------------------------------------
#sub _check_delete_result
#{
#}

#sub delete_post
#{
#}

#------------------------------------------------------------------------------------------------
#----------------------------------------- BAN CHECK --------------------------------------------
#------------------------------------------------------------------------------------------------
#sub _check_ban_result
#{
#}

#sub ban_check
#{
#}

#------------------------------------------------------------------------------------------------
#----------------------------------  OTHER METHODS  ---------------------------------------------
#------------------------------------------------------------------------------------------------
#sub get_page
#{
#}

#sub get_thread
#{
#}

1;
