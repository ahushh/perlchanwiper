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
 
sub echo_msg($;$$)
{
    my ($p, $msg, $type) = @_;
    return 0 unless $p;

    printf "[%s]",    get_time;
    printf "[%-10s]", $type    if $type;
    printf " %s\n",   $msg,    if $msg;

    return 1;
}

sub echo_proxy($$$$$)
{
    no warnings;
    my $print_proxy = sub
    {
        my ($proxy, $color) = @_;
        print colored [$color], sprintf " %-40s ", $proxy;
    };
    
    my ($p, $color, $proxy, $type, $msg) = @_;
    return 0 unless $p;
     
    echo_msg(1, "", $type);
     
    &$print_proxy($proxy, $color);
    print "$msg\n";

    return 1;
}

1;
 
 
 
