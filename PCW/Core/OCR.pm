package PCW::Core::OCR;

use v5.12;
use utf8;
use Moo;
use Carp qw/croak/;
use Module::Runtime qw/use_module/;

has 'object' => (
    is       => 'lazy'
);

has 'config' => (
    is       => 'rw',
    required => 1,
);

has 'log' => (
    is    => 'rw',
);

sub _build_object
{
    my $self  = shift;
    my $class = 'PCW::OCR::' . $self->config->{mode};
    use_module($class) or croak "Couldn't load $class $@";
    return $class->new();
}

#------------------------------------------------------------------------------------------------

sub solve
{
    my ($self, $file_path) = @_;
    my $after   = $self->config->{after} || sub { $_[0] };
    my $captcha = &$after( $self->object->solve($self, $file_path) );
    return "" unless $captcha;
    utf8::decode($captcha);
    return $captcha;
}

sub report_bad
{
    my ($self, $file_path) = @_;
    return $self->object->report_bad($self, $file_path);
}

1;
