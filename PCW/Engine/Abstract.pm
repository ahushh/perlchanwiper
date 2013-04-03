package PCW::Engine::Abstract;

#------------------------------------------------------------------------------------------------
use v5.12;
use Moo;
use utf8;
use Carp qw/croak/;

#------------------------------------------------------------------------------------------------
use POSIX qw/isdigit/;

has 'agents' => (
    is      => 'rw',
    default => sub { ['Mozilla/5.0 (Windows; I; Windows NT 5.1; ru; rv:1.9.2.13) Gecko/20100101 Firefox/4.0'] },
);

has 'log' => (
    is       => 'rw',
    required => 1,
);

has 'verbose' => (
    is   => 'rw',
    required => 1,
);

has 'chan_config' => (
    is   => 'rw',
    required => 1,
);

has 'common_config' => (
    is   => 'rw',
    required => 1,
);

has 'ocr' => (
    is   => 'rw',
);

has 'data' => (
    is => 'rw',
);

#------------------------------------------------------------------------------------------------
#----------------------------------  PRIVATE METHODS  -------------------------------------------
#------------------------------------------------------------------------------------------------

#------------------------------------------------------------------------------------------------
# URL
#------------------------------------------------------------------------------------------------
sub _get_url_post
{
    croak("This method is abstract and cannot be called directly.");
}

sub _get_url_delete
{
    croak("This method is abstract and cannot be called directly.");
}

sub _get_url_captcha
{
    croak("This method is abstract and cannot be called directly.");
}

sub _get_url_page
{
    croak("This method is abstract and cannot be called directly.");
}

sub _get_url_thread
{
    croak("This method is abstract and cannot be called directly.");
}

#------------------------------------------------------------------------------------------------
# HTML
#------------------------------------------------------------------------------------------------
sub get_replies
{
    croak("This method is abstract and cannot be called directly.");
}

sub get_threads
{
    croak("This method is abstract and cannot be called directly.");
}

sub is_thread_on_page
{
    croak("This method is abstract and cannot be called directly.");
}

#------------------------------------------------------------------------------------------------
# headers
#------------------------------------------------------------------------------------------------
sub _get_headers_post
{
    croak("This method is abstract and cannot be called directly.");
}

sub _get_headers_captcha
{
    croak("This method is abstract and cannot be called directly.");
}

sub _get_headers_delete
{
    croak("This method is abstract and cannot be called directly.");
}

sub _get_headers_default
{
    croak("This method is abstract and cannot be called directly.");
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
    croak("This method is abstract and cannot be called directly.");
}

#------------------------------------------------------------------------------------------------
sub _check_post_result
{
    croak("This method is abstract and cannot be called directly.");
}

sub make_post
{
    croak("This method is abstract and cannot be called directly.");
}

#------------------------------------------------------------------------------------------------
# DELETE
#------------------------------------------------------------------------------------------------
sub _check_delete_result
{
    croak("This method is abstract and cannot be called directly.");
}

sub delete_post
{
    croak("This method is abstract and cannot be called directly.");
}

#------------------------------------------------------------------------------------------------
#----------------------------------------- BAN CHECK --------------------------------------------
#------------------------------------------------------------------------------------------------
sub _check_ban_result
{
    croak("This method is abstract and cannot be called directly.");
}

sub ban_check
{
    croak("This method is abstract and cannot be called directly.");
}

#------------------------------------------------------------------------------------------------
#----------------------------------  OTHER METHODS  ---------------------------------------------
#------------------------------------------------------------------------------------------------
sub get_page
{
    croak("This method is abstract and cannot be called directly.");
}

sub get_thread
{
    croak("This method is abstract and cannot be called directly.");
}

1;
