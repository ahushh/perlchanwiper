#!/usr/bin/perl -w
$|=1;

our $VERSION = '0.2';
 
use strict;
use autodie;
use lib '.';
 
use Carp;
use feature qw/say switch/;
 
use Getopt::Long; 
use File::Basename; 
use File::Temp qw/tempdir/;

use PCW::Modes::Wipe;
use PCW::Modes::Delete;
use PCW::Modes::Bump;
use PCW::Modes::ProxyChecker;
use PCW::Utils qw(get_proxylist);
 
#-----------------------------------------------------------------------------
# Common variables
#-----------------------------------------------------------------------------
my $common_config = 'config.pl';
our %mode_config;
our $chan_config;
 
my @proxies;
my @agents;
my $engine;
#-----------------------------------------------------------------------------
# Functions
#-----------------------------------------------------------------------------
sub info($$$)
{
    my ($chan, $mode, $proxies) = @_;
    say "Perl Chan Wiper v$VERSION";
    say "~" x 30;
    say "Chan: $chan";
    say "Work mode: $mode";
    say "Proxies loaded: $proxies";
    say "~" x 30;
}
 
#-----------------------------------------------------------------------------
# Parse command line arguments
#-----------------------------------------------------------------------------
#-- DEFAULT VALUES
my $chan;
my $mode;
my $debug   = 0;
my $verbose = 0;
my $useragents = 'UserAgents';
my $proxy_file = 'proxy/no';
my $proxy_type = 'http';
 
sub init()
{
    my $help = 0;
    my $result = GetOptions(
        'chan=s'    => \$chan,
        'mode=s'    => \$mode,
        'proxy=s'   => \$proxy_file,
        'ua=s'      => \$useragents,
        'debug'     => \$debug,
        'verbose'   => \$verbose,
        'help|?'    => \$help,
    );
    if ($help || !($mode && $chan))
    {
        usage();
        exit 1;
    }
    $mode = lc($mode);
}
 
sub check_user_error()
{
    my $modes_list = 'proxychecker|wipe|delete|bump';
     
    Carp::croak("Chan config '$chan' does not exist")
        unless($chan || -e "chans/$chan.pl");

    Carp::croak("Common config '$common_config' does not exist")
        unless($common_config || -e $common_config);

    Carp::croak("Mode '$mode' does not exist")
        unless($mode =~ /$modes_list/i);
         
    #--- it is... a programmer error
    Carp::croak("Mode '$mode' config does not exist")
        unless(-e "configs/$mode.pl");
    #--
         
    Carp::croak("Proxylist '$proxy_file' does not exist")
        unless($proxy_file && -e $proxy_file);
         
    Carp::croak("Proxy type '$proxy_type' is not specified")
        unless($proxy_type);
         
    Carp::croak("Useragents list '$useragents' does not exist")
        unless($useragents && -e $useragents);
}
 
#-----------------------------------------------------------------------------
# Usage
#-----------------------------------------------------------------------------
sub usage
{
    my @modes;
    for my $path (glob "PCW/Modes/*.pm")
    {
        my ($mode, undef, undef) = fileparse($path, '.pm');
        push @modes, lc($mode);
    }
    my @chans;
    for my $path (glob "chans/*.pl")
    {
        my ($chan, undef, undef) = fileparse($path, '.pl');
        push @chans, $chan;
    }
    my @engines;
    for my $path (glob "PCW/Engine/*.pm")
    {
        my ($engine, undef, undef) = fileparse($path, '.pm');
        push @engines, $engine;
    }
 
    local $" = ', ';
    print <<DESU
PerlChanWiper - cli tool for imageboard
 
Usage: $0 [chan] [mode]...

Options:
    --chan          Chan name (@chans)
    --mode          Work mode (@modes)
    --proxy         Proxy file (default is '$proxy_file')
    --proxytype     Default proxy protocol (default is '$proxy_type')
    --ua            Userg agents list file (default is '$useragents')
    --debug         Enable debug output
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
    require "configs/$mode.pl";  #-- load %mode_config
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
    my $package = "chans/$chan.pl";
    require "$package"; #-- load $chan_config
}

sub load_engine()
{
    my $package = "PCW::Engine::". $chan_config->{engine};
    eval("use $package");
    Carp::croak($@) if ($@);
    $engine = $package->new(agents => \@agents, debug => $debug, verbose => $verbose);
}
 
#-----------------------------------------------------------------------------
init();            
check_user_error();
load_configs();     #-- load %mode_config
load_proxies();     
load_agents();
load_chan();        #-- load %chan_config
load_engine();
#-----------------------------------------------------------------------------
 
#-----------------------------------------------------------------------------
info($chan, $mode, scalar @proxies); #-- Show info
#config_checker($mode, %args);                 #-- Check for config errors
##-----------------------------------------------------------------------------

##-----------------------------------------------------------------------------
if ($mode =~ /wipe/) 
{
    $PCW::Modes::Wipe::DEBUG   = $debug;
    $PCW::Modes::Wipe::VERBOSE = $verbose;
    PCW::Modes::Wipe->wipe($engine, $chan_config, proxies => \@proxies, %mode_config);
}
elsif ($mode =~ /delete/)
{
    $PCW::Modes::Delete::DEBUG   = $debug;
    $PCW::Modes::Delete::VERBOSE = $verbose;
    PCW::Modes::Delete->delete($engine, $chan_config, proxies => \@proxies, %mode_config);
}
elsif ($mode =~ /proxychecker/)
{
    $PCW::Modes::ProxyChecker::DEBUG   = $debug;
    $PCW::Modes::ProxyChecker::VERBOSE = $verbose;
    PCW::Modes::ProxyChecker->checker($engine, $chan_config, proxies => \@proxies, %mode_config);
}
elsif ($mode =~ /bump/)
{
    $PCW::Modes::Bump::DEBUG   = $debug;
    $PCW::Modes::Bump::VERBOSE = $verbose;
    PCW::Modes::Bump->bump($engine, $chan_config, proxies => \@proxies, %mode_config);
}

__END__
