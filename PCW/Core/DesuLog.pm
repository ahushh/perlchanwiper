package PCW::Core::DesuLog;

use v5.12;
use Moo;
use Carp qw/croak/;
use utf8;

use Term::ANSIColor;
use Time::Local;
use POSIX qw/strftime isdigit/;
use IO::Handle;

has 'level' => (
    is       => 'rw',
    isa      => sub { croak "bad log level" unless isdigit $_[0] },
    required => 1,
);

has 'file' => (
    is       => 'ro',
    required => 1,
);

has 'clolored' => (
    is         => 'rw',
);

has 'settings' => (
    is       => 'rw',
    required => 1,
);

sub BUILDARGS
{
    my ($class, %args) = @_;
    my $fh;
    if ($args{file})
    {
        open $fh, '>:utf8', $args{file};
        $fh->autoflush(1);
    }
    $args{file} = $fh || *STDOUT;
    return { %args };
}


#------------------------------------------------------------------------------------------------
# PRIVATE
#------------------------------------------------------------------------------------------------
sub _with_color
{
    my ($t, $color, $msg) = @_;
    return $msg unless $t;
    return colored [$color], $msg;
}

#------------------------------------------------------------------------------------------------
# METHODS
#------------------------------------------------------------------------------------------------
# 0 - no text logged
# 1 - something logged
sub msg
{
    my ($self, $l, $msg, $type, $color) = @_;
    croak "Bad error type '$l'" unless defined $self->settings->{$l};

    return 0 if $self->level < $self->settings->{$l};
    my $fh    = $self->file;

    print  $fh strftime("[%H:%M:%S]", localtime(time));
    printf $fh "[%15s]", $type         if $type;
    say $fh _with_color($self->colored, $color, " $msg") if $msg;
    return 1;
}

#------------------------------------------------------------------------------------------------
# 0 - no text logged
# 1 - something logged
sub pretty_proxy
{
    my ($self, $l, $color, $proxy, $type, $msg) = @_;
    croak("Bad error type '$l'") unless defined $self->settings->{$l};

    return 0 if $self->level < $self->settings->{$l};
    my $fh    = $self->file;

    $self->msg($l, undef, $type); #-- print time and error type
    print $fh _with_color($self->colored, $color, sprintf(" %-30s ", $proxy));
    say $fh $msg;

    return 1;
}

1;
