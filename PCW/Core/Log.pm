package PCW::Core::Log;
use feature qw(switch say);

use strict;
use autodie;
use Carp;

use Term::ANSIColor;
use Time::Local;
use POSIX qw/strftime/;
use IO::Handle;

#------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------
sub new($%)
{
    my ($class, %args) = @_;
    my $level      = delete $args{level};
    my $file       = delete $args{file};
    my $colored    = delete $args{colored};

    my @k = keys %args;
    Carp::croak("These options aren't defined: @k")
        if %args;

    my $fh;
    if ($file)
    {
        open $fh, '>', $file;
        $fh->autoflush(1);
    }
    my $self = {};
    $self->{level}   = $level;
    $self->{file}    = $fh || *STDOUT;
    $self->{colored} = $colored;
    bless $self, $class;

}

sub msg($$;$$$)
{
    my ($self, $l, $msg, $type, $color) = @_;
    return 0 if $self->{level} < $l;
    my $fh    = $self->{file};
    undef $color unless $self->{colored};

    print  $fh strftime("[%H:%M:%S]", localtime(time));
    printf $fh "[%15s]", $type if $type;
    say    $fh colored [$color], " $msg" if $msg;
    return 1;
}

sub pretty_proxy($$$$$$)
{
    my ($self, $l, $color, $proxy, $type, $msg) = @_;
    return 0 if $self->{level} < $l;
    my $fh    = $self->{file};
    undef $color unless $self->{colored};

    $self->msg($l, undef, $type); #-- print time and type
    print $fh colored [$color], sprintf(" %-40s ", $proxy);
    say $fh $msg;

    return 1;
}

1;
