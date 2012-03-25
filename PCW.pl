#!/usr/bin/perl
$|=1;

our $VERSION = '0.2';

use strict;
use autodie;
use lib 'lib';

#-----------------------------------------------------------------------------
use Carp;
use feature qw/say switch/;

#-----------------------------------------------------------------------------
use Getopt::Long;
use File::Basename;
use File::Temp qw/tempdir/;
use File::Spec;

#-----------------------------------------------------------------------------
use PCW::Modes::Wipe;
use PCW::Modes::Delete;
use PCW::Modes::AutoBump;
use PCW::Modes::ProxyChecker;
use PCW::Core::Utils qw(get_proxylist);

#-----------------------------------------------------------------------------
# Common variables
#-----------------------------------------------------------------------------
my $common_config = 'config.pl';
our %mode_config;
our $chan_config;
our $mode_config;

my @proxies;
my @agents;
my $engine;

#-----------------------------------------------------------------------------
# Parse command line arguments
#-----------------------------------------------------------------------------
#-- DEFAULT VALUES
my $chan;
my $mode;
my $loglevel   = 1;
my $verbose    = 0;
my $useragents = 'UserAgents';
my $proxy_file = 'proxy/no';
my $proxy_type = 'http';

sub init()
{
    my $help   = 0;
    my $result = GetOptions(
        'chan=s'     => \$chan,
        'mode=s'     => \$mode,
        'proxy=s'    => \$proxy_file,
        'ua=s'       => \$useragents,
        'cconfig=s'  => \$common_config,
        'mconfig=s'  => \$mode_config,
        'loglevel=i' => \$loglevel,
        'verbose'    => \$verbose,
        'help|?'     => \$help,
    );
    if ($help || !($mode && $chan))
    {
        usage();
        exit 1;
    }
    $mode = lc($mode);
    $mode_config = File::Spec->catfile('configs', "$mode.pl")
        unless $mode_config;
}

sub check_user_error()
{
    my $modes_list = 'proxychecker|wipe|delete|autobump';

    Carp::croak("Chan config '$chan' does not exist")
        unless($chan || -e "chans/$chan.pl");

    Carp::croak("Common config '$common_config' does not exist")
        unless($common_config || -e $common_config);

    Carp::croak("Mode '$mode' does not exist")
        unless($mode =~ /$modes_list/i);

    Carp::croak("Mode '$mode' config does not exist")
        unless(-e "configs/$mode.pl");

    Carp::croak("Proxylist '$proxy_file' does not exist")
        unless($proxy_file && -e $proxy_file);

    Carp::croak("Proxy type '$proxy_type' is not specified")
        unless($proxy_type);

    Carp::croak("Useragents list '$useragents' does not exist")
        unless($useragents && -e $useragents);
}

#-----------------------------------------------------------------------------
# Info
#-----------------------------------------------------------------------------
sub info()
{
    say "Perl Chan Wiper v$VERSION";
    say "~" x 30;
    say "Chan: $chan ". ($chan_config ? "($chan_config->{name})" : "");
    say "Engine: ". $chan_config->{engine};
    say "Work mode: $mode";
    say "Mode config: $mode_config";
    say "Common config: $common_config";
    say "Proxies loaded: ". scalar @proxies;
    say "Browsers loaded: ". scalar @agents;
    say "~" x 30;
    say "Log level: $loglevel";
    say "Verbose output: $verbose";
    say "~" x 30;
}

#-----------------------------------------------------------------------------
# Usage
#-----------------------------------------------------------------------------
sub usage
{
    my @modes;
    for my $path (glob "PCW/Modes/*.pm")
    {
        next if $path =~ /Common/;
        my ($mode, undef, undef) = fileparse($path, '.pm');
        push @modes, lc($mode);
    }
    my @chans;
    for my $path (glob "chans/*.pl")
    {
        next if $path =~ /example/;
        my ($chan, undef, undef) = fileparse($path, '.pl');
        push @chans, $chan;
    }
    my @engines;
    for my $path (glob "PCW/Engine/*.pm")
    {
        next if $path =~ /Abstract|Simple/;
        my ($engine, undef, undef) = fileparse($path, '.pm');
        push @engines, $engine;
    }

    local $" = ', ';
    print <<DESU
PerlChanWiper - a multifunction CLI tool for different imageboards

Usage: $0 [chan] [mode]...

Options:
    --chan          Chan name (@chans)
    --mode          Work mode (@modes)
    --proxy         Proxy file (default is '$proxy_file')
    --proxytype     Default proxy protocol (default is '$proxy_type')
    --ua            User agents list file (default is '$useragents')
    --cconfig       Common config file (default is '$common_config')
    --mconfig       Mode config file (default is 'configs/\$mode_name.pl')
    --loglevel      Log level (1-4, 1 — the least and default)
    --verbose       Verbose output
    --help          Show this message and exit

Supported chan engines: @engines
Version $VERSION
DESU
}

#-----------------------------------------------------------------------------
# Load
#-----------------------------------------------------------------------------
sub load_configs()
{
    our ($img, $msg, $captcha_decode);
    require $common_config;
    require $mode_config;  #-- load %mode_config
    if ($mode =~ /bump|wipe/)
    {
        $mode_config{img_data} = $img;
        $mode_config{msg_data} = $msg;
        $mode_config{captcha_decode} = $captcha_decode;
    }
}

sub load_proxies()
{
    @proxies = get_proxylist($proxy_file, $proxy_type);
}

sub load_agents()
{
    open my $fh, '<', $useragents;
    @agents = <$fh>;
    close $fh;
}

sub load_chan()
{
    my $package = File::Spec->catfile('chans', "$chan.pl");
    require "$package"; #-- load $chan_config
}

sub load_engine()
{
    my $package = "PCW::Engine::". $chan_config->{engine};
    eval("use $package");
    Carp::croak($@) if ($@);
    $engine = $package->new(%$chan_config, agents => \@agents, loglevel => $loglevel, verbose => $verbose);
}

#-----------------------------------------------------------------------------
init();
check_user_error();
load_configs();     #-- load %mode_config
load_proxies();
load_agents();
load_chan();        #-- load $chan_config
load_engine();
#-----------------------------------------------------------------------------

#-----------------------------------------------------------------------------
info(); #-- Show info
#config_checker($mode, %args);                 #-- Check for common config errors
##-----------------------------------------------------------------------------

##-----------------------------------------------------------------------------
if ($mode =~ /wipe/)
{
    $PCW::Modes::Wipe::LOGLEVEL = $loglevel;
    $PCW::Modes::Wipe::VERBOSE  = $verbose;
    PCW::Modes::Wipe->wipe($engine, proxies => \@proxies, %mode_config);
}
elsif ($mode =~ /delete/)
{
    $PCW::Modes::Delete::LOGLEVEL = $loglevel;
    $PCW::Modes::Delete::VERBOSE  = $verbose;
    PCW::Modes::Delete->delete($engine, proxies => \@proxies, %mode_config);
}
elsif ($mode =~ /proxychecker/)
{
    $PCW::Modes::ProxyChecker::LOGLEVEL = $loglevel;
    $PCW::Modes::ProxyChecker::VERBOSE  = $verbose;
    PCW::Modes::ProxyChecker->checker($engine, proxies => \@proxies, %mode_config);
}
elsif ($mode =~ /autobump/)
{
    $PCW::Modes::AutoBump::LOGLEVEL = $loglevel;
    $PCW::Modes::AutoBump::VERBOSE  = $verbose;
    PCW::Modes::AutoBump->bump($engine, proxies => \@proxies, %mode_config);
}

#__END__
