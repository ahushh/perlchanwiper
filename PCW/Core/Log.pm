package PCW::Core::Log;

use Exporter 'import';
our @EXPORT_OK = qw(echo_msg echo_msg_dbg echo_proxy echo_proxy_dbg);
 
use strict;
use autodie;
use Carp;

use Term::ANSIColor;
use feature qw(switch);

#------------------------------------------------------------------------------------------------
#---------------------------------------------- LOG ---------------------------------------------
#------------------------------------------------------------------------------------------------
sub get_time()
{
    my ($sec, $min, $hour) = localtime; 
    $sec  = "0$sec"  if (length $sec == 1);
    $min  = "0$min"  if (length $min == 1);
    $hour = "0$hour" if (length $hour == 1);
    "$hour:$min:$sec";
}
 
sub echo_msg(;$$)
{
    my ($msg, $type) = @_;
    print sprintf "[%s]", get_time;
    print "[$type]" if $type;
    print " $msg\n" if $msg;
}

sub echo_msg_dbg($$;$)
{
    my ($debug, $msg, $type) = @_;
    echo_msg($msg, $type) if $debug;
}
 
sub echo_proxy($$$$)
{
    no warnings;
    my $print_proxy = sub
    {
        my ($proxy, $color) = @_;
        print colored [$color], sprintf " %-40s ", $proxy;
    };
    
    my ($color, $proxy, $type, $msg) = @_;
    echo_msg("", $type);
     
    &$print_proxy($proxy, $color);
    print "$msg\n";
}

sub echo_proxy_dbg($$$$$)
{
    my ($debug, $color, $proxy, $type, $msg) = @_;
    echo_proxy($color, $proxy, $type, $msg) if $debug;
}
 
1;
 
 
 
