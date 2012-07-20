#!/usr/bin/perl
use v5.12;
use Pod::Usage;

my $OS      = $ARGV[0];
my $sudo    = 'sudo ' if $ENV{USER} ne 'root';
system 'aptitude'; #-- check if aptitude is installed
my $deb_cmd = ($? ? 'apt-get' : 'aptitude' ) . ' install';

my @base = qw/
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
LWP::Protocol::https
LWP::Protocol::socks
JavaScript::Engine
File::Which
/;
my @webui = qw/
Mojolicious::Lite
HTML::FromANSI
/;
my @proxychecker = qw/
WWW::ProxyChecker
/;

my %H = (
         debian  => {
                     base         => {
                                      $sudo .$deb_cmd => [ qw/
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
                                                           /
                                                         ]
                                     },
                     webui        => {
                                      $sudo .$deb_cmd => [ 'libmojolicious-perl' ],
                                      $sudo .'cpan'   => [ 'HTML::FromANSI'      ],
                                     },
                     proxychecker => {
                                      $sudo .'cpan' => [ @proxychecker ]
                                     }
                    },
         arch    => {
                     base         => {
                                      $sudo .'yaourt -S' => [ qw/
                                                            perl-yaml-syck
                                                            perl-anyevent
                                                            perl-carp-clan
                                                            perl-coro
                                                            perl-data-random
                                                            perl-getopt-long
                                                            perl-html-parser
                                                            perl-list-moreutils
                                                            perl-params-util
                                                            ruby-term-ansicolor
                                                            perl-data-random
                                                            perl-file-find-rule
                                                            perl-libwww
                                                            perl-lwp-protocol-https
                                                            perl-lwp-protocol-socks
                                                            perl-javascript-spidermonkey
                                                            perl-string-shellquote
                                                            perl-file-which
                                                            /
                                                          ]
                                     },
                     webui        => { $sudo .'cpan' => [ @webui        ] },
                     proxychecker => { $sudo .'cpan' => [ @proxychecker ] },
                    },
         gentoo  => {
                     base         => { $sudo ."g-cpan -i" => [ @base, 'String::ShellQuote' ] },
                     webui        => { $sudo ."g-cpan -i" => [ @webui        ] },
                     proxychecker => { $sudo ."g-cpan -i" => [ @proxychecker ] },
                    },
         windows => {
                     base         => { 'cpan' => [ @base, 'Win32::ShellQuote' ] },
                     proxychecker => { 'cpan' => [ @proxychecker ] },
                    },
         other   => {
                     base         => { $sudo ."cpan" => [ @base, 'String::ShellQuote' ] },
                     proxychecker => { $sudo ."cpan" => [ @proxychecker ] },
                     webui        => { $sudo ."cpan" => [ @webui        ] },
                    }
        );

pod2usage(-verbose => 2) if !$OS or !(map { $OS =~ /^$_$/ } keys(%H));

my @parts = ();
my %parts = (
             base         => 'Would you like to install base modules (they all are necessary)? [y/n] ',
             webui        => 'Modules for web-interface? [y/n] ',
             proxychecker => 'Modules for proxychecker? [y/n] ',
            );

for my $p (keys %{ $H{$OS} } )
{
    print $parts{$p};
    yesno(sub { push @parts, $p; }, sub {} );
}

for (@parts)
{
    say "---- Now installing $_ modules ----";
    for my $cmd (keys %{ $H{$OS}->{$_} })
    {
        my @mod = @{ $H{$OS}->{$_}{$cmd} };
        say "$cmd @mod\n";
        system "$cmd @mod";
        if ($?)
        {
            print "\n'$cmd @mod' exit abnormally with code $? \nContinue? [y/n] ";
            yesno( sub {}, sub { exit; } );
        }
    }
}

sub yesno(&&)
{
    my ($yes, $no) = @_;
    while (1)
    {
        my $a = <STDIN>;
        given ($a)
        {
            when (/y/) { return &$yes                }
            when (/n/) { return &$no;                }
            default    { say 'Please answer y or n'; }
        }
    }

}

__END__
=head1 NAME

Install script

=head1 SYNOPSIS 

./INSTALL.pl [debian|gentoo|arch|other]

perl .\INSTALL.pl windows

=head1 Linux

=over

=item *

Perl is need to be updated to 5.12 or above.

If you really want to run this on perl 5.10, try this:

    grep -rl 'v5.12' | xargs sed -i 's/v5.12/v5.10/g'

But it maybe won't work properly

=item *

Install tesseract or tesseract-ocr (program which will be used to solve captcha) and imagemagick from repositories.

Something like that

    sudo apt-get install tesseract-ocr imagemagick

    sudo emerge imagemagick tesseract

=item *

If you use debian-based distro, install libssl-dev lib (is necessary for socks-proxy, https and some other things):

    sudo apt-get install libssl-dev

Dunno what its name is in other distros. Everything is ok without this library on gentoo.

=back

=over

=item B<Install all required perl packages>

=over

=item I<Debian/Ubuntu/... (via apt and cpan)>

    ./INSTALL.pl debian

=item I<Gentoo (required g-cpan)>

    ./INSTALL.pl gentoo

=item I<Arch (via yaourt and cpan)>

    ./INSTALL.pl arch

=item I<Everything else (via cpan)>

    ./INSTALL.pl other

=back 

=back 

=head2

Checked out on Gentoo (perl v5.14.2)

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

perl \.INSTALL.pl windows

=back

Almost not tested
