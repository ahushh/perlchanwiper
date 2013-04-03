package PCW::Engine::Simple;

#------------------------------------------------------------------------------------------------
use v5.12;
use Hash::Util "lock_keys";
use Moo;
use utf8;
use Carp qw/croak/;

extends 'PCW::Engine::Abstract';

#------------------------------------------------------------------------------------------------
use Data::Random qw/rand_set/;
use HTTP::Headers;

use PCW::Core::Utils   qw/merge_hashes parse_cookies html2text save_file unrandomize took get_recaptcha/;
use PCW::Core::Net     qw/http_get http_post/;
use PCW::Data::Images  qw/make_pic/;
use PCW::Data::Text    qw/make_text/;

#------------------------------------------------------------------------------------------------
#----------------------------------  PRIVATE METHODS  -------------------------------------------
#------------------------------------------------------------------------------------------------

#------------------------------------------------------------------------------------------------
# URL
#------------------------------------------------------------------------------------------------
sub _get_url_post
{
    my ($self, $post_fields) = @_;
    return $self->chan_config->{urls}{post};
}

sub _get_url_delete
{
    my ($self, $post_fields) = @_;
    return $self->chan_config->{urls}{delete};
}

sub _get_url_captcha
{
    my ($self, $post_fields) = @_;
    return $self->chan_config->{urls}{captcha};
}

sub _get_url_page
{
    my ($self, $post_fields) = @_;
    if ($post_fields->{page})
    {
        return sprintf $self->chan_config->{urls}{page}, $post_fields->{board}, $post_fields->{page};
    }
    else
    {
        return sprintf $self->chan_config->{urls}{zero_page}, $post_fields->{board};
    }
}

sub _get_url_thread
{
    my ($self, $post_fields) = @_;
    return sprintf $self->chan_config->{urls}{thread}, $post_fields->{board}, $post_fields->{thread};
}

#------------------------------------------------------------------------------------------------
# HTML
#------------------------------------------------------------------------------------------------
sub get_replies
{
    croak 'get_replies not emplemented yet';
}

sub get_threads
{
    croak 'get_threads not emplemented yet';
}

sub is_thread_on_page
{
    croak 'is_thread_on_page not emplemented yet';
}

#------------------------------------------------------------------------------------------------
# headers
#------------------------------------------------------------------------------------------------
sub _get_headers_post
{
    my ($self, $post_fields) = @_;
    my $referer = ($post_fields->{thread} ? $self->_get_url_thread($post_fields) : $self->_get_url_page($post_fields));
    my %h = %{ $self->chan_config->{headers}{post} };
    $h{Referer} = $referer;
    return \%h;
}

sub _get_headers_captcha
{
    my ($self, $post_fields) = @_;
    my $referer = ($post_fields->{thread} ? $self->_get_url_thread($post_fields) : $self->_get_url_page($post_fields));
    my %h = %{ $self->chan_config->{headers}{captcha} };
    $h{Referer} = $referer;
    return \%h;
}

sub _get_headers_delete
{
    my ($self, $post_fields) = @_;
    my $h = \%{ $self->chan_config->{headers}{default} };
    return $h;
}

sub _get_headers_default
{
    my ($self, $post_fields) = @_;
    my $h = \%{ $self->chan_config->{headers}{default} };
    return $h;
}

#------------------------------------------------------------------------------------------------
# Content
#------------------------------------------------------------------------------------------------
sub _get_fields_post
{
    croak("This method is abstract and cannot be called directly.");
}

sub _get_fields_delete
{
    croak("This method is abstract and cannot be called directly.");
}

#------------------------------------------------------------------------------------------------
#--------------------------------------- MAIN METHODS -------------------------------------------
#------------------------------------------------------------------------------------------------

#------------------------------------------------------------------------------------------------
sub get_captcha
{
    croak("This method is abstract and cannot be called directly.");
}

#------------------------------------------------------------------------------------------------
sub prepare_data
{
    croak("This method is abstract and cannot be called directly.");
}

#------------------------------------------------------------------------------------------------
sub handle_captcha
{
    my ($self, $task, undef) = @_;
    my %content      = %{ merge_hashes( $self->_get_fields_post( $task->{post_fields} ),
                                        $self->chan_config->{fields}{post}) };
    $task->{content} = { ($task->{content} ? %{$task->{content}} : ()), %content };

    # добавить проверку на включенную капчу
    if ($task->{path_to_captcha})
    {
        my $took;
        my $captcha_text = took { $self->ocr->solve($task->{path_to_captcha}) } \$took;
        unless (defined $captcha_text)
        {
            $self->log->pretty_proxy('ENGINE_HANDLE_CAPTCHA_ERROR', 'red', $task->{proxy}, 'HANDLE CAPTCHA', "captcha recognizer returned undef (took $took sec.)");
            return('error');
        }
        unless ($captcha_text or $captcha_text =~ s/\s//gr)
        {
            $self->log->pretty_proxy('ENGINE_HANDLE_CAPTCHA_ERROR', 'red', $task->{proxy}, 'HANDLE CAPTCHA', "captcha recognizer returned an empty string (took $took sec.)");
            return('no_text');
        }

        $self->log->pretty_proxy('ENGINE_HANDLE_CAPTCHA', 'green', $task->{proxy}, 'HANDLE CAPTCHA', "solved captcha: $captcha_text (took $took sec.)");
        $task->{content}{ $self->chan_config->{fields}{post}{_captcha} } = $captcha_text;
        $task->{captcha_text}                      = $captcha_text;
    }
    return('success');
}

#------------------------------------------------------------------------------------------------
sub _check_post_result
{
    my ($self, $response, $code, $task, $post_fields) = @_;

    while (my ($type, $errors) = each %{ $self->chan_config->{response}{post} })
    {
        my ($color, $loglvl);
        given ($type)
        {
            when (/critical_error|banned|net_error/)                 { $color = 'red'   ; $loglvl = 'ENGINE_MAKE_POST_ERROR' }
            when (/same_message|too_fast|post_error|wrong_captcha/)  { $color = 'yellow'; $loglvl = 'ENGINE_MAKE_POST_ERROR' }
            when (/success/)                                         { $color = 'green' ; $loglvl = 'ENGINE_MAKE_POST'     }
        }

        for (@$errors)
        {
            if ($response =~ /$_/ || $code =~ /$_/)
            {
                $self->log->pretty_proxy($loglvl, $color, $task->{proxy}, 'MAKE POST',
                            sprintf("[%s](%d){%s}", uc($type), $code, ($self->verbose ? html2text($response) : $_)));
                return($type);
            }
        }
    }

    $self->log->pretty_proxy('ENGINE_MAKE_POST_ERROR', 'yellow', $task->{proxy}, 'MAKE POST',
        sprintf("[%s](%d){%s}", 'UNKNOWN', $code, ($self->verbose ? html2text($response) : 'unknown error')));
    return('unknown');
}

sub make_post
{
    my ($self, $task, $post_fields) = @_;
    my $post_url = $self->_get_url_post( $post_fields );
    my $response =
        http_post(proxy   => $task->{proxy}  , url     => $post_url,
                  headers => $task->{headers}, content => $task->{content});

    return $self->_check_post_result($response->{content}, $response->{code}, $task, $post_fields);
}

#------------------------------------------------------------------------------------------------
# DELETE
#------------------------------------------------------------------------------------------------
# sub _check_delete_result
# {
#     my ($self, $response, $code, $task, $cnf) = @_;

#     for (my ($type, $errors) = each %{ $self->chan_config->{response}{delete} })
#     {
#         my ($color, $loglvl);
#         given ($type)
#         {
#             when (/error|wrong_password/) { $color = 'red'  ; $loglvl = 'ENGN_DELETE_ERROR' }
#             when (/success/)              { $color = 'green'; $loglvl = 'ENGN_DELETE'     }
#         }

#         for (@$errors)
#         {
#             if ($response =~ /$_/ || $code =~ /$_/)
#             {
#                 $self->log->pretty_proxy($loglvl, $color, $task->{proxy}, "DELETE $task->{delete}",
#                             sprintf("[%s](%d){%s}", uc($type), $code, ($self->verbose ? html2text($response) : $_)));
#                 return($type);
#             }
#         }
#     }
#     $self->log->pretty_proxy('ENGN_DELETE_ERROR', 'yellow', $task->{proxy}, "DELETE $task->{delete}",
#         sprintf("[%s](%d){%s}", 'UNKNOWN', $code, ($self->verbose ? html2text($response) : 'unknown error')));
#     return('unknown');
# }

# sub delete_post
# {
#     my ($self, $task, $cnf) = @_;

#     #-- Set headers
#     # какие аргументы нужно передавать в хидеры?
#     my $headers = HTTP::Headers->new(%{ $self->_get_headers_delete($task) });
#     $headers->user_agent(rand_set(set => $self->agents));

#     #-- Make content
#     my %content = %{ merge_hashes($self->_get_fields_delete($task), $self->chan_config->{fields}{delete}) };

#     #-- Send request
#     my $response = http_post(proxy   => $task->{proxy}, url     => $self->_get_url_delete( $task ),
#                              headers => $headers      , content => \%content);

#     return $self->_check_delete_result($response->{content}, $response->{code}, $task, $cnf);
# }

# #------------------------------------------------------------------------------------------------
# #----------------------------------------- BAN CHECK --------------------------------------------
# #------------------------------------------------------------------------------------------------
# sub _check_ban_result
# {
#     # my ($self, $response, $code, $task, $cnf) = @_;
#     # my $log = $self->{log};

#     # for (my ($type, $errors) = each $self->chan_config->{response}{post})
#     # {
#     #     my ($color, $loglvl);
#     #     given ($type)
#     #     {
#     #         when (/banned|critical_error|net_error/) { $color = 'red'  ; $loglvl = 'ENGN_CHECK_ERROR' }
#     #         default                                  { $color = 'green'; $loglvl = 'ENGN_CHECK'     }
#     #     }
#     #     for (@$errors)
#     #     {
#     #         if ($response =~ /$_/ || $code =~ /$_/)
#     #         {
#     #             $self->log->pretty_proxy($loglvl, $color, $task->{proxy}, 'CHECK',
#     #                         sprintf("[%s](%d){%s}", uc($type), $code, ($self->{verbose} ? html2text($response) : $_)));
#     #             return($type);
#     #         }
#     #     }
#     # }

#     # $self->log->pretty_proxy('ENGN_CHECK_ERROR', 'yellow', $task->{proxy}, 'CHECK',
#     #     sprintf("[%s](%d){%s}", 'UNKNOWN', $code, ($self->{verbose} ? html2text($response) : 'unknown error')));

#     # return('unknown');
# }

# sub ban_check
# {
#     # my ($self, $task, $cnf) = @_;

#     # $task->{post_fields} = unrandomize( $cnf->{post_fields} );
#     # my $post_headers = HTTP::Headers->new(%{ $self->_get_headers_post($task->{post_fields}) });
#     # $post_headers->user_agent(rand_set(set => $self->agents));
#     # $task->{headers} = $post_headers;

#     # my %content = %{ merge_hashes( $self->_get_fields_post( $task->{post_fields} ), $self->chan_config->{fields}{post}) };

#     # #---- Form data
#     # if ($cnf->{message}{text})
#     # {
#     #     my $text = make_text( $self, $task, $cnf->{message} );
#     #     $content{ $self->chan_config->{fields}{post}{msg} } = $text;
#     # }
#     # #-- Image
#     # if ($cnf->{image}{mode} ne 'no')
#     # {
#     #     my $file_path = make_pic( $self, $task, $cnf->{image} );
#     #     $content{ $self->chan_config->{fields}{post}{img} } = ( $file_path ? [$file_path] : undef );
#     #     $task->{file_path} = $file_path;
#     # }
#     # elsif (!$task->{post_fields}{thread}) #-- New thread
#     # {
#     #     $content{ $self->chan_config->{fields}{post}{nofile} } = 'on';
#     # }

#     # $task->{content} = \%content;

#     # #-- POSTING
#     # my $response =
#     #     http_post(proxy   => $task->{proxy}  , url     => $self->_get_url_post( $task->{post_fields} ),
#     #               headers => $task->{headers}, content => $task->{content});

#     # return $self->_check_ban_result($response->{content}, $response->{code}, $task, $cnf);
# }

#------------------------------------------------------------------------------------------------
#----------------------------------  OTHER METHODS  ---------------------------------------------
#------------------------------------------------------------------------------------------------
# sub get_page
# {
#     my ($self, $task, $cnf) = @_;
#     #-- Set headers
#     my $headers = HTTP::Headers->new(%{ $self->_get_headers_default() });
#     $headers->user_agent(rand_set(set => $self->{agents}));
#     #-- Send request
#     my $response =
#         http_get(proxy => $task->{proxy}, url => $self->_get_url_page($cnf), headers => $headers);

#     return $response->{content}, $response->{headers}, $response->{status};
# }

# sub get_thread
# {
#     my ($self, $task, $cnf) = @_;
#     #-- Set headers
#     my $headers = HTTP::Headers->new(%{ $self->_get_default_headers() });
#     $headers->user_agent(rand_set(set => $self->{agents}));
#     #-- Send request
#     my $response = 
#         http_get(proxy => $task->{proxy}, url => $self->_get_thread_url($cnf), headers => $headers);

#     return $response->{content}, $response->{headers}, $response->{status};
# }

1;
