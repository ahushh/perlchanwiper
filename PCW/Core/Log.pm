package PCW::Core::Log;

use v5.12;
use utf8;
use autodie;
use Carp;

use Term::ANSIColor;
use Time::Local;
use POSIX qw/strftime/;
use IO::Handle;

#------------------------------------------------------------------------------------------------
sub _with_color($$$)
{
    my ($t, $color, $msg) = @_;
    return $msg unless $t;
    return colored [$color], $msg;
}

#------------------------------------------------------------------------------------------------
sub new($%)
{
    my ($class, %args) = @_;
    my $level      = delete $args{level};
    my $file       = delete $args{file};
    my $colored    = delete $args{colored};
    my $settings   = delete $args{settings};

    my @k = keys %args;
    Carp::croak("These options aren't defined: @k") if %args;

    my $fh;
    if ($file)
    {
        open $fh, '>:utf8', $file;
        $fh->autoflush(1);
    }
    my $self = {};
    $self->{level}    = $level;
    $self->{file}     = $fh || *STDOUT;
    $self->{colored}  = $colored;
    $self->{settings} = $settings;
    bless $self, $class;

}
sub msg($$;$$$)
{
    my ($self, $l, $msg, $type, $color) = @_;
    return 0 if $self->{level} < $self->{settings}{$l};
    my $fh    = $self->{file};

    print  $fh strftime("[%H:%M:%S]", localtime(time));
    printf $fh "[%15s]", $type         if $type;
    say $fh _with_color($self->{colored}, $color, " $msg") if $msg;
    return 1;
}

sub pretty_proxy($$$$$$)
{
    my ($self, $l, $color, $proxy, $type, $msg) = @_;
    return 0 if $self->{level} < $self->{settings}{$l};
    my $fh    = $self->{file};

    $self->msg($l, undef, $type); #-- print time and the type
    print $fh _with_color($self->{colored}, $color, sprintf(" %-30s ", $proxy));
    say $fh $msg;

    return 1;
}

1;
