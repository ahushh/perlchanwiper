package PCW::Engine::EFGKusaba;

#------------------------------------------------------------------------------------------------
use v5.12;
use Hash::Util "lock_keys";
use Moo;
use utf8;
use Carp qw/croak/;

extends 'PCW::Engine::Kusaba';

with 'PCW::Roles::Engine::MM';

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

sub _get_url_captcha
{
    my ($self, $post_fields) = @_;
    return $self->chan_config->{urls}{captcha} . "?" . rand;
}

#sub _get_url_page
#{
#}

#sub _get_url_thread
#{
#}

#------------------------------------------------------------------------------------------------
# HTML
#------------------------------------------------------------------------------------------------
#sub get_replies
#{
#}

#sub get_threads
#{
#}

#sub is_thread_on_page
#{
#}

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
    my $content = PCW::Engine::Kusaba::_get_fields_post(@_);
    $content->{mm} = 0;
    return $content;
}

#sub _get_fields_delete
#{
#}

#------------------------------------------------------------------------------------------------
#--------------------------------------- MAIN METHODS -------------------------------------------
#------------------------------------------------------------------------------------------------

#------------------------------------------------------------------------------------------------
#sub get_captcha
#{
#}

#------------------------------------------------------------------------------------------------
#sub handle_captcha
#{
#}

#------------------------------------------------------------------------------------------------
#sub prepare_data
#{
#}

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
