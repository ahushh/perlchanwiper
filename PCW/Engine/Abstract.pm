package PCW::Engine::Abstract;

#------------------------------------------------------------------------------------------------
# Абстрактный класс, предоставляющий интерфейс для модов (mode)
#------------------------------------------------------------------------------------------------
use strict;
use utf8;
use autodie;
use Carp;

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
    Carp::croak("This method is abstract and cannot be called directly.");
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
    Carp::croak("This method is abstract and cannot be called directly.");
}

# $self, %args -> (string)
sub _get_delete_url($%)
{
    Carp::croak("This method is abstract and cannot be called directly.");
}

# $self, %args -> (string)
sub _get_captcha_url($%)
{
    Carp::croak("This method is abstract and cannot be called directly.");
}

# $self, %args -> (string)
sub _get_page_url($%)
{
    Carp::croak("This method is abstract and cannot be called directly.");
}

# $self, %args -> (string)
sub _get_thread_url($%)
{
    Carp::croak("This method is abstract and cannot be called directly.");
}

#------------------------------------------------------------------------------------------------
# HTML
#------------------------------------------------------------------------------------------------
# $self, $html -> %posts
# %posts:
#  (integer) => (string)
sub get_all_replies($$)
{
    Carp::croak("This method is abstract and cannot be called directly.");
}

# $self, $html -> %posts
# %posts:
#  (integer) => (string)
sub get_all_threads($$)
{
    Carp::croak("This method is abstract and cannot be called directly.");
}

# $self, %cnf -> (boolean)
# %cnf:
#  (integer) => thread
#  (integer) => page
sub is_thread_on_page($%)
{
    Carp::croak("This method is abstract and cannot be called directly.");
}

#------------------------------------------------------------------------------------------------
# headers
#------------------------------------------------------------------------------------------------
sub _get_post_headers($%)
{
    Carp::croak("This method is abstract and cannot be called directly.");
}

sub _get_captcha_headers($%)
{
    Carp::croak("This method is abstract and cannot be called directly.");
}

sub _get_delete_headers($%)
{
    Carp::croak("This method is abstract and cannot be called directly.");
}

sub _get_default_headers($%)
{
    Carp::croak("This method is abstract and cannot be called directly.");
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
    Carp::croak("This method is abstract and cannot be called directly.");
}

# $self, $task, $cnf -> $status_str
sub post($$$$)
{
    Carp::croak("This method is abstract and cannot be called directly.");
}

#------------------------------------------------------------------------------------------------
# DELETE
#------------------------------------------------------------------------------------------------
# $self, $response, $code, $task, $cnf -> $status_str
sub _check_delete_result($$$$$)
{
    Carp::croak("This method is abstract and cannot be called directly.");
}

# $self, $task, $cnf -> $status_str
sub delete($$$$)
{
    Carp::croak("This method is abstract and cannot be called directly.");
}

#------------------------------------------------------------------------------------------------
#----------------------------------------- BAN CHECK --------------------------------------------
#------------------------------------------------------------------------------------------------
# $self, $response, $code, $task, $cnf -> $status_str
sub _check_ban_result($$$$$)
{
    Carp::croak("This method is abstract and cannot be called directly.");
}

# $self, $task, $cnf -> $status_str
sub ban_check($$$)
{
    Carp::croak("This method is abstract and cannot be called directly.");
}

#------------------------------------------------------------------------------------------------
#----------------------------------  OTHER METHODS  ---------------------------------------------
#------------------------------------------------------------------------------------------------
# $self, $task, $cnf -> $response, $response, $headers, $status_line
sub get_page($$$)
{
    Carp::croak("This method is abstract and cannot be called directly.");
}

# $self, $task, $cnf -> $response, $response, $headers, $status_line
sub get_thread($$$)
{
    Carp::croak("This method is abstract and cannot be called directly.");
}

1;
