package PCW::Data::Images;

use v5.12;
use utf8;
use Carp;
use autodie;

use Exporter 'import';
our @EXPORT_OK = qw/make_pic/;

#------------------------------------------------------------------------------------------------
use File::Basename;
use File::Find::Rule;
use File::Copy;
use File::Temp         qw/tempfile/;
use File::Which        qw/which/;
use List::Util         qw/shuffle reduce/;
use Data::Random       qw/rand_set rand_image/;
#------------------------------------------------------------------------------------------------
use PCW::Core::Utils   qw/random shellquote readfile/;

use Coro;
my $lock = Coro::Semaphore->new;
#------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------
sub make_pic($$$)
{
    my ($engine, $task, $conf) = @_;
    my $img_mode = $conf->{mode} . '_img';
    Carp::croak sprintf "Image mode '%s' doesn't exist!\n", $conf->{mode}
            unless exists &{ $img_mode };
    my $create_img = \&{ $img_mode };
    return &$create_img($engine, $task, $conf);
}

#------------------------------------------------------------------------------------------------
# Internal functions
#------------------------------------------------------------------------------------------------
sub captcha_img($$$)
{
    my (undef, $task, $data) = @_;
    return if defined $task->{test};
    return img_altering($task->{path_to_captcha}, $data->{altering})
        if $data->{altering};
    return $task->{path_to_captcha};
}

sub rand_img($$$)
{
    my (undef, $task, $data) = @_;
    return if defined $task->{test};
    my ($fh, $filename) = tempfile(UNLINK => 1, SUFFIX => ".png");
    my %opt = %{ $data->{args} } if $data->{args};
    print $fh rand_image(%opt);
    close $fh;
    return $filename;
}

sub single_img($)
{
    my (undef, $task, $data) = @_;
    return if defined $task->{test};
    my $path_to_img = $data->{path};

    return img_altering($path_to_img, $data->{altering})
        if $data->{altering};
    return $path_to_img;
}

sub dir_img($)
{
    my ($engine, $task, $data) = @_;
    return if defined $task->{test};
    my $dirs = $data->{path};
    my $log  = $engine->{log};

    state @img_list;
    $lock->down;
    if (!@img_list or !$data->{loaded})
    {
        my @types = @{ $data->{types} };
        my $rule =  File::Find::Rule->new;
        $rule->size("<=". $data->{max_size}) if $data->{max_size};
        $rule->name(map { "*.$_" } @types);
        $rule->maxdepth(1) unless $data->{recursively};
        @img_list = $rule->file()->in(@$dirs);
       
        @img_list = grep { basename($_) =~ /$data->{regexp}/ } @img_list if $data->{regexp};
        $log->msg('DATA_LOADED', scalar(@img_list)." images loaded.");
        return undef unless @img_list;
        $data->{loaded} = 1;
    }
    $lock->up;
    state $i = 0;

    my $path_to_img;
    if ($data->{order} eq 'random')
    {
        $path_to_img = ${ rand_set(set => \@img_list) };
    }
    else
    {
        $i = 0 if ($i >= scalar @img_list);
        $path_to_img = $img_list[$i++];
    }
    return img_altering($path_to_img, $data->{altering})
        if $data->{altering};
    return $path_to_img;
}

sub img_altering($)
{
    my ($full_name, $conf) = @_;
    my ($name, $path, $suffix) = fileparse($full_name, 'png', 'jpeg', 'jpg', 'gif', 'bmp');

    unless ($suffix)
    {
        warn "$full_name is not an image file. Skipping altering...";
        return $full_name;
    }

    my $mode = $conf->{mode};
    my ($fh, $filename) = tempfile(UNLINK => 1, SUFFIX => ".$suffix");
    binmode $fh;

    my $interpolate = sub {
        my $_ = shift;
        s|%(\d+)rand(\d+)%|random($1, $2);|eg;
        s|%(\d+)digits%|join('',map{int(rand(10))}(1..$1))|eg;
        s|%source%|shellquote($full_name);|eg;
        s|%dest%|shellquote($filename);|eg;
        return $_;
    };

    given ($mode)
    {
        when ('randnums')
        {
            my $img    = readfile($full_name);
            my $digits = join '', map {int rand 10} &$interpolate($conf->{number_nums});
            print $fh $img;
            print $fh $digits;
            print $fh $conf->{sign} if $conf->{sign};
            close $fh;
        }
        when ('randbytes')
        {
            my $img = readfile($full_name);
            print $fh $img;
            print $fh reduce { $a . chr(int(rand() * 256)) } ('', 1..&$interpolate($conf->{number_bytes}));
            print $fh $conf->{sign} if $conf->{sign};
            close $fh;
        }
        when ('convert')
        {
            close $fh;
            my $convert = $conf->{convert} || which('convert');
            my $args    = &$interpolate($conf->{args});
            system("$convert $args");
            if ($conf->{sign})
            {
                open my $fh1, '>>', $filename;
                print $fh $conf->{sign};
                close $fh;
            }
        }
    }
    return $filename;
}

1;
