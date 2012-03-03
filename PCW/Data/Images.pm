package PCW::Data::Images;

use strict;
use Carp;
use autodie;
use feature 'state';

use Exporter 'import';
our @EXPORT_OK = qw(make_pic);

use File::Basename;
use File::Copy;
use File::Temp qw(tempfile tempdir);

use List::Util qw(shuffle);
use Data::Random qw(rand_set rand_image);
use PCW::Core::Utils qw(random);

sub make_pic($)
{
    my $conf = shift;
    my $img_mode = $conf->{mode} . '_img';
    Carp::croak sprintf "Image mode '%s' doesn't exist!\n", $conf->{mode}
			unless exists &{ $img_mode };
    my $create_img = \&{ $img_mode };
    return &$create_img($conf);
}

#------------------------------------------------------------------------------------------------
#---------------------------------------- Images ------------------------------------------------
#------------------------------------------------------------------------------------------------
sub no_img($)
{
    undef;
}

sub rand_img($)
{
    my $data = shift;
    my ($fh, $filename) = tempfile(UNLINK => 1, SUFFIX => ".png");
    my %opt = %{ $data->{args} } if $data->{args};
    print $fh rand_image(%opt);
    close $fh;
    return $filename;
}

sub single_img($)
{
    my $data = shift;
    Carp::croak "Image file is not set!" unless my $path_to_img = $data->{path};
	Carp::croak "The file size greaten then max size allowed!" if int((-s $path_to_img)/1024) > $data->{max_size};
     
    return img_altering($path_to_img, $data->{altering})
        if $data->{altering};
    return $path_to_img;
}

sub dir_img($)
{
    my $data = shift;
    my $dirs = $data->{path};
     
    state @img_list;
    if (!@img_list)
    {
        my $types = $data->{types};
        Carp::croak "Allowed types are not specified!"
                unless $types;
        my $s;
        $s .= "$_," for (@$types);
        chop $s;
         
        @img_list = (@img_list, glob "$_/*.{$s}")
            for (@$dirs);

        Carp::croak "Image dir is empty!"
                unless @img_list;
        @img_list = grep { int((-s $_)/1024) <= $data->{max_size} } @img_list
            if $data->{max_size};
    }
     

    state $i = 0;
     
    my $path_to_img;
    if ($data->{order} eq 'random')
    {
        $path_to_img = ${ rand_set(set => \@img_list) };
    }
    elsif ($data->{order} eq 'normal')
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
    my ($name, $path, $suffix) = fileparse($full_name, 'png', 'jpeg', 'jpg', 'gif');
     
    unless ($suffix)
    {
        warn "$full_name is not an image file.";
        return $full_name;
    }
     
    my $mode = $conf->{mode};
     
    my ($fh, $filename) = tempfile(UNLINK => 1, SUFFIX => ".$suffix");

    if ($mode eq 'addrand')
    {
		open my $img_fh, "<", $full_name;
		my $img;
		{
			local $/ = undef;
			$img = <$img_fh>;
            close($img_fh);
		}
		print $fh $img;
		my $n = $conf->{number_nums};
        for (my $i = 0; $i < $n; $i++)
        {
            print $fh int(rand(10));
        }
        close($fh);
    }
    elsif ($mode eq 'resize')
    {
    	close($fh);
        my $convert = $conf->{convert};
        my $args    = $conf->{args};
		my $k = random($conf->{min}, $conf->{max});
		system("$convert $args -resize $k% $full_name $filename");
    }
    elsif ($mode eq 'convert')
    {
    	close($fh);
        my $convert = $conf->{convert};
        my $args    = $conf->{args};
		system("$convert $args $full_name $filename");
    }
    else
    {
        warn "Image altering methode '$mode' does not exist."; 
        close($fh);
        return $full_name;
    }
    return $filename;
}
 
1;
