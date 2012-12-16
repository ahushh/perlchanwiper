package PCW::Engine::EFGKusaba;

use v5.12;
use utf8;
use Carp;

use base 'PCW::Engine::Kusaba';

#------------------------------------------------------------------------------------------------
# Importing utility packages
#------------------------------------------------------------------------------------------------
use File::Temp   qw/tempfile/;
use Data::Random qw/rand_set/;
use FindBin      qw/$Bin/;
use HTTP::Headers;

#------------------------------------------------------------------------------------------------
# Import internal PCW packages
#------------------------------------------------------------------------------------------------
use PCW::Core::Utils    qw/merge_hashes parse_cookies html2text save_file unrandomize took/;
use PCW::Core::Captcha  qw/captcha_recognizer/;
use PCW::Core::Net      qw/http_get http_post get_recaptcha/;
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
# sub _get_post_url($%)
# {
# }

# $self, %args -> (string)
# sub _get_delete_url($%)
# {
# }

# $self, %args -> (string)
sub _get_captcha_url($$%)
{
    my ($self, %config) = @_;
    return $self->{urls}{captcha} . "?" . rand;
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
# sub _get_catalog_url($%)
# {
# }

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
# sub is_thread_on_page($%)
# {
# }

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
                   'MAX_FILE_SIZE' => 10240000,
                   'email'         => $email,
                   'subject'       => $subject,
                   'password'      => $password,
                   'thread'        => $thread,
                   'board'         => $board,
                   'mm'            => 0,
                  };
    $content->{nofile} = $nofile if $nofile;
    return $content;
}

# sub _get_delete_content($$%)
# {
# }

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
# sub get($$$$)
# {
# }

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

#-- Helper function
sub compute_mm($)
{
    no warnings;
    my $s  = shift;
    my ($fh, $file) = tempfile(SUFFIX=>"--pcw.txt");
    print $fh $s;
    close $fh;
    my $mm_cmd='var Utf8={encode:function(c){c=c.replace(/\r\n/g,"\n");var f="";for(var g=0;g<c.length;g++){var h=c.charCodeAt(g);if(h<128){f+=String.fromCharCode(h)}else{if((h>127)&&(h<2048)){f+=String.fromCharCode((h>>6)|192);f+=String.fromCharCode((h&63)|128)}else{f+=String.fromCharCode((h>>12)|224);f+=String.fromCharCode(((h>>6)&63)|128);f+=String.fromCharCode((h&63)|128)}}}return f},decode:function(f){var c="";var h=0;var g=c1=c2=0;while(h<f.length){g=f.charCodeAt(h);if(g<128){c+=String.fromCharCode(g);h++}else{if((g>191)&&(g<224)){c2=f.charCodeAt(h+1);c+=String.fromCharCode(((g&31)<<6)|(c2&63));h+=2}else{c2=f.charCodeAt(h+1);c3=f.charCodeAt(h+2);c+=String.fromCharCode(((g&15)<<12)|((c2&63)<<6)|(c3&63));h+=3}}}return c}};function mm(a){a=Utf8.encode(a);var m=a.length,i=2^m,k=0,l,q=1540483477,r=255,h=65535;while(m>=4){l=((a.charCodeAt(k)&r))|((a.charCodeAt(++k)&r)<<8)|((a.charCodeAt(++k)&r)<<16)|((a.charCodeAt(++k)&r)<<24);l=(((l&h)*q)+((((l>>>16)*q)&h)<<16));l^=l>>>24;l=(((l&h)*q)+((((l>>>16)*q)&h)<<16));i=(((i&h)*q)+((((i>>>16)*q)&h)<<16))^l;m-=4;++k}switch(m){case 3:i^=(a.charCodeAt(k+2)&r)<<16;case 2:i^=(a.charCodeAt(k+1)&r)<<8;case 1:i^=(a.charCodeAt(k)&r);i=(((i&h)*q)+((((i>>>16)*q)&h)<<16))}i^=i>>>13;i=(((i&h)*q)+((((i>>>16)*q)&h)<<16));i^=i>>>15;var c=i>>>0;return c};'. "print(mm(read(\"$file\")))";
    my $mm = sprintf "$Bin/lib/v8 -e '%s'", $mm_cmd;
    my $result =`$mm`;
    unlink $file;
    return($result+0);
}

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
    if ($cnf->{vid_data}{mode} and $cnf->{vid_data}{mode} ne 'no')
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
    }
    elsif (!$task->{post_cnf}{thread}) #-- New thread
    {
        $content{ $self->{fields}{post}{nofile} } = 'on';
    }

    #-- Compute mm cookie
    if ($content{board} eq 'b')
    {
        my ($took, $mm);
        #-- if the text is empty or the text is static, compute mm only once
        if (($cnf->{msg_data}{text} eq '' or $cnf->{msg_data}{text} !~ /#|%|@~/)
            and !$self->{static_mm})
        {
            $self->{static_mm} = took { compute_mm($content{mm} . $content{message} . $content{postpassword}) } \$took;
            $log->pretty_proxy('ENGN_EFG_MM', 'green', $task->{proxy}, 'PREPARE', "computed mm: $self->{static_mm} (took $took sec.)");
        }
        if ($self->{static_mm})
        {
            $mm = $self->{static_mm};
        }
        else
        {
            $mm = took { compute_mm($content{mm} . $content{message} . $content{postpassword}) } \$took;
            $log->pretty_proxy('ENGN_EFG_MM', 'green', $task->{proxy}, 'PREPARE', "computed mm: $mm (took $took sec.)");
        }
        #-- Add mm to post headers
        my $h = $task->{headers};
        my $c = $h->header('Cookie');
        $c =~ s/\s*$//;
        $h->header('Cookie' => "$c; mm2=1; mm=$mm");
    }

    $task->{content} = \%content;

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
# $self, $task, $cnf -> $response, $response, $headers, $status_line
#sub get_page($$$)
#{
#}

# $self, $task, $cnf -> $response, $response, $headers, $status_line
#sub get_thread($$$)
#{
#}

# $self, $task, $cnf -> $response, $response, $headers, $status_line
# sub get_catalog($$$)
# {
# }

1;
