#!/usr/bin/perl
use v5.12;
use Pod::Usage;

my @packages = qw/
YAML
AnyEvent
Coro
Data::Random
Getopt::Long
HTML::Entities
List::MoreUtils
List::Util
Term::ANSIColor
Data::Random
File::Find::Rule
WWW::ProxyChecker
LWP::Protocol::https
LWP::Protocol::socks
JavaScript::Engine
File::Which
/;

my @debian = qw/
libyaml-libyaml-perl
libanyevent-perl
libcoro-perl
libdata-random-perl
libgetopt-long-descriptive-perl
libhtml-parser-perl
liblist-moreutils-perl
libscalar-list-utils-perl
ruby-term-ansicolor
libdata-random-perl
libfile-find-rule-perl-perl
libwww-perl
liblwp-protocol-https-perl
liblwp-protocol-socks-perl
libje-perl
libstring-shellquote-perl
libfile-which-perl
/;

if ($ARGV[0] eq 'windows')
{
    push @packages, 'Win32::ShellQuote';
}
else
{
    push @packages, 'String::ShellQuote';
}

given ($ARGV[0])
{
    when ('debian' ) { system "sudo apt-get install @debian" }
    when ('gentoo' ) { system "sudo g-cpan @packages"        }
    when ('windows') { system "cpan @packages"               }
    default          { pod2usage(-verbose => 2);             }
}

__END__
=head1 NAME

Install script

=head1 SYNOPSIS 

./INSTALL.pl [debian|gentoo|windows|cpan]

=head1 Linux

=over

=item *

Perl is need to be updated to 5.12 or above

If you really want to run this on perl 5.10, try this:

    grep -rl 'v5.12' | xargs sed -i 's/v5.12/v5.10/g'

=item *

Install tesseract or tesseract-ocr (program which will be used to solve captcha) and imagemagick from repositories

    sudo apt-get install tesseract-ocr imagemagick

=item *

If you use debian-based distro, install libssl-dev lib (is necessary for socks-proxy, https and some other things):

    sudo apt-get install libssl-dev

Dunno what its name is in other distros. Everything is ok without this library on gentoo.

=back

=over

=item B<Install all required perl packages>

=over

=item I<Debian/Ubuntu (via apt)>

    ./INSTALL.pl debian


=item I<Gentoo (required g-cpan)>

    ./INSTALL.pl gentoo

=item I<Everything else>

    ./INSTALL.pl cpan

=back 

=back 

=head2

Checked out on Ubuntu 12.04 LTS (perl 5.14.2) and Gentoo (perl 5.12.4 and 5.14.2)

=head1 Windows

Install these programs:

=over

=item B<Perl>

  http://strawberryperl.com/ or http://www.activestate.com/activeperl/downloads

=item B<Imagemagick>

  http://www.imagemagick.org/script/binary-releases.php#windows

=item B<Tesseract-OCR>

  http://code.google.com/p/tesseract-ocr/downloads/list

=back

=over

=item B<Install all required perl packages>

perl ./INSTALL.pl windows

=back 
