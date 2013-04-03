package PCW::Data::Images;

use v5.12;
use Moo;
use utf8;
use Carp qw/croak/;
use autodie;

has 'image_list' => (
    is => 'rw',
);

has 'loaded' => (
    is      => 'rw',
    default => sub { 0 },
);

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
our $lock = Coro::Semaphore->new;
#------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------
sub fetch
{
    my ($self, $engine, $task, $img_conf) = @_;
    return if defined $task->{test};
    my $function   = '_' . $img_conf->{mode} . '_img';
    croak "Image mode not defined!" unless $img_conf->{mode};
    croak sprintf "Image mode '%s' doesn't exist!", $img_conf->{mode}
            unless exists &{ $function };

    $self->load($engine,$task,$img_conf) unless $self->loaded;
    my $create_img = \&{ $function };
    my $image_path = &$create_img($self, $engine, $task, $img_conf);
    $img_conf->{altering} ? 
        $self->_img_altering($engine, $image_path, $img_conf->{altering}) :
        $image_path;
}

sub load
{
    my ($self, $engine, $task, $img_conf) = @_;
    return if $img_conf->{mode} ne 'dir';
    my $dirs = $img_conf->{path};

    $lock->down;
    my @img_list;
    my @types = @{ $img_conf->{types} };
    my $rule =  File::Find::Rule->new;
    $rule->size("<=". $img_conf->{max_size}) if $img_conf->{max_size};
    $rule->name(map { "*.$_" } @types);
    $rule->maxdepth(1) unless $img_conf->{recursively};
    @img_list = $rule->file()->in(@$dirs);

    @img_list = grep { basename($_) =~ /$img_conf->{regexp}/ } @img_list if $img_conf->{regexp};
    $engine->log->msg('DATA_LOADED', scalar(@img_list)." images loaded.");
    if (@img_list)
    {
        $img_conf->{loaded} = 1;
        $self->image_ist(\@img_list);
    }
    $lock->up;
}

#------------------------------------------------------------------------------------------------
# Internal functions
#------------------------------------------------------------------------------------------------
sub _captcha_img
{
    my ($self, undef, $task, $img_conf) = @_;
    return $task->{path_to_captcha};
}

sub _rand_img
{
    my ($self, undef, $task, $img_conf) = @_;
    my ($fh, $filename) = tempfile(UNLINK => 1, SUFFIX => ".png");
    my %opt = %{ $img_conf->{args} } if $img_conf->{args};
    print $fh rand_image(%opt);
    close $fh;
    return $filename;
}

sub _single_img
{
    my ($self, undef, $task, $img_conf) = @_;
    return $img_conf->{path};
}

sub _dir_img
{
    my ($self, $engine, $task, $img_conf) = @_;

    state $i = 0;

    my $path_to_img;
    if ($img_conf->{order} eq 'random')
    {
        $path_to_img = ${ rand_set(set => $self->image_list) };
    }
    else
    {
        # don't copy!
        my @imgs = @{ $self->image_list };
        $i = 0 if ($i >= scalar @imgs);
        $path_to_img = $imgs[$i++];
    }
    return $path_to_img;
}

sub _img_altering
{
    my ($self, $engine, $full_name, $img_conf) = @_;
    my ($name, $path, $suffix) = fileparse($full_name, 'png', 'jpeg', 'jpg', 'gif', 'bmp');

    unless ($suffix)
    {
        $engine->log->msg('DATA_LOADED', " $full_name is not an image file. ");
        return $full_name;
    }

    my $mode = $img_conf->{mode};
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
            my $digits = join '', map {int rand 10} &$interpolate($img_conf->{number_nums});
            print $fh $img;
            print $fh $digits;
            print $fh $img_conf->{sign} if $img_conf->{sign};
            close $fh;
        }
        when ('randbytes')
        {
            my $img = readfile($full_name);
            print $fh $img;
            print $fh reduce { $a . chr(int(rand() * 256)) } ('', 1..&$interpolate($img_conf->{number_bytes}));
            print $fh $img_conf->{sign} if $img_conf->{sign};
            close $fh;
        }
        when ('convert')
        {
            close $fh;
            my $convert = $img_conf->{convert} || which('convert');
            my $args    = &$interpolate($img_conf->{args});
            system("$convert $args");
            if ($img_conf->{sign})
            {
                open my $fh1, '>>', $filename;
                print $fh $img_conf->{sign};
                close $fh;
            }
        }
    }
    return $filename;
}

1;
