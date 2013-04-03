package PCW::Roles::Engine::MM;

use v5.12;
use Moo::Role;
use File::Temp       qw/tempfile/;
use File::Which      qw/which/;
use PCW::Core::Utils qw/took/;

requires 'prepare_data';

has 'static_mm' => (
    is => 'rw',
    default => sub {0},
);

sub _compute_mm
{
    no warnings;
    my $message  = shift;
    my ($fh, $file) = tempfile(SUFFIX => "--mm-pcw.txt");
    print $fh $message;
    close $fh;
    my $mm_cmd='var Utf8={encode:function(c){c=c.replace(/\r\n/g,"\n");var f="";for(var g=0;g<c.length;g++){var h=c.charCodeAt(g);if(h<128){f+=String.fromCharCode(h)}else{if((h>127)&&(h<2048)){f+=String.fromCharCode((h>>6)|192);f+=String.fromCharCode((h&63)|128)}else{f+=String.fromCharCode((h>>12)|224);f+=String.fromCharCode(((h>>6)&63)|128);f+=String.fromCharCode((h&63)|128)}}}return f},decode:function(f){var c="";var h=0;var g=c1=c2=0;while(h<f.length){g=f.charCodeAt(h);if(g<128){c+=String.fromCharCode(g);h++}else{if((g>191)&&(g<224)){c2=f.charCodeAt(h+1);c+=String.fromCharCode(((g&31)<<6)|(c2&63));h+=2}else{c2=f.charCodeAt(h+1);c3=f.charCodeAt(h+2);c+=String.fromCharCode(((g&15)<<12)|((c2&63)<<6)|(c3&63));h+=3}}}return c}};function mm(a){a=Utf8.encode(a);var m=a.length,i=2^m,k=0,l,q=1540483477,r=255,h=65535;while(m>=4){l=((a.charCodeAt(k)&r))|((a.charCodeAt(++k)&r)<<8)|((a.charCodeAt(++k)&r)<<16)|((a.charCodeAt(++k)&r)<<24);l=(((l&h)*q)+((((l>>>16)*q)&h)<<16));l^=l>>>24;l=(((l&h)*q)+((((l>>>16)*q)&h)<<16));i=(((i&h)*q)+((((i>>>16)*q)&h)<<16))^l;m-=4;++k}switch(m){case 3:i^=(a.charCodeAt(k+2)&r)<<16;case 2:i^=(a.charCodeAt(k+1)&r)<<8;case 1:i^=(a.charCodeAt(k)&r);i=(((i&h)*q)+((((i>>>16)*q)&h)<<16))}i^=i>>>13;i=(((i&h)*q)+((((i>>>16)*q)&h)<<16));i^=i>>>15;var c=i>>>0;return c};'. "print(mm(read(\"$file\")))";
    my $mm = sprintf "%s -e '%s'", which('d8'), $mm_cmd;
    my $result =`$mm`;
    unlink $file;
    return($result+0);
}

after prepare_data => sub {
    my ($self, $task, $post_fields) = @_;

    if ($task->{content}{board} eq 'b')
    {
        my ($took, $mm);
        #-- if the text is empty or the text is static, compute mm only once
        if (($self->common_config->{message}{text} eq '' or $self->common_config->{message}{text} !~ /#|%|@~/)
            and !$self->static_mm)
        {
            $self->static_mm( took { _compute_mm($task->{content}{mm} . $task->{content}{message} . $task->{content}{postpassword}) } \$took );
            $self->log->pretty_proxy('ENGINE_EFG_MM', 'green', $task->{proxy}, 'PREPARE DATA', "computed mm: ".$self->static_mm ." (took $took sec.)");
        }
        if ($self->static_mm)
        {
            $mm = $self->static_mm;
        }
        else
        {
            $mm = took { _compute_mm($task->{content}{mm} . $task->{content}{message} . $task->{content}{postpassword}) } \$took;
            $self->log->pretty_proxy('ENGINE_EFG_MM', 'green', $task->{proxy}, 'PREPARE DATA', "computed mm: $mm (took $took sec.)");
        }

        my $h = $task->{headers};
        my $c = $h->header('Cookie');
        $c =~ s/\s*$//;
        $h->header('Cookie' => "$c; mm2=1; mm=$mm");
    }

    return('success');
};

1;
