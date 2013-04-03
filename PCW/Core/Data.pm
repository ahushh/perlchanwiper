package PCW::Core::Data;

use v5.12;
use Moo;

use PCW::Data::Images;
use PCW::Data::Text;
use PCW::Data::Video;

has 'image' => (
    is      => 'ro',
    default => sub { PCW::Data::Images->new() }
);

has 'text' => (
    is      => 'ro',
    default => sub { PCW::Data::Text->new() }
);

has 'video' => (
    is      => 'ro',
    default => sub { PCW::Data::Video->new() }
);

1;
