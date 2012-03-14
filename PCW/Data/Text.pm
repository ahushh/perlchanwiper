package PCW::Data::Text;

use strict;
use Carp;
use autodie;
use feature ':5.10';

use Exporter 'import';
our @EXPORT_OK = qw(make_text);

use List::Util qw(shuffle);
use Data::Random qw(rand_set);

use PCW::Core::Utils qw(random);

sub interpolate($)
{
    my $text = shift;
     
    my $now = time;
    $text =~ s/%unixtime%/$now/g;
     
    my $date_string = scalar localtime($now);
    $text =~ s/%date%/$date_string/g;
     
    return $text;
}
 
sub make_text($)
{
    my $conf = shift;
    my $msg_mode = $conf->{mode} . '_msg';
    my $sign     = $conf->{sign} || '';
    Carp::croak sprintf "Text mode '%s' doesn't exist!\n", $conf->{mode}
			unless exists &{ $msg_mode };
    my $create_msg = \&{ $msg_mode };
    my $text = &$create_msg($conf) . $sign;
    return interpolate($text);
}

#------------------------------------------------------------------------------------------------
#---------------------------------------- Text --------------------------------------------------
#------------------------------------------------------------------------------------------------
sub no_msg($)
{
    undef;
}

sub single_msg($)
{
    my $data = shift;
    $data->{text};
}

sub boundary_msg($)
{
    my $data = shift;
    my $boundary = $data->{boundary} || '----';
    state @text;
    state $i = 0;
    if (!@text)
    {
        open(my $fh, '<', $data->{path});
		local $/ = undef;
        my $text = <$fh>;
		@text = split /$boundary/, $text;
        close $fh;
    }
    my $msg;
    if ($data->{order} eq 'random')
    {
        $msg = ${ rand_set(set => \@text) };
    }
    elsif ($data->{order} eq 'normal')
    {
        $i = 0 if ($i >= scalar @text);
        $msg = $text[$i++];
    }
    return $msg;
}

sub string_msg($)
{
    my $data = shift;
    state @text;
    state $i = 0;
    $i = 0 if ($i >= scalar @text);
    if (!@text)
    {
        open(my $fh, "<", $data->{path});
        @text = <$fh>;
        close $fh;
    }
    my $num_str = $data->{num_str};
    my $msg;
    for (@text)
    {
        last unless $num_str--;
        if ($data->{order} eq 'normal')
        {
            $i = 0 if ($i >= scalar @text);
            $msg .= $text[$i++];
        }
        elsif ($data->{order} eq 'random')
        {
            $msg = ${ rand_set(set => \@text) };
        }
        $msg .= "\n";
    }
    return $msg;
}

sub delirium_msg(;$)
{
    my $cnf = shift;
    my $min_len_w = $cnf->{min_len_w} || 3;
    my $max_len_w = $cnf->{max_len_w} || 7;
    my $min_w     = $cnf->{min_w}     || 1;
    my $max_w     = $cnf->{max_w}     || 10;
    my $min_q     = $cnf->{min_q}     || 3;
    my $max_q     = $cnf->{max_q}     || 20;
    my $sep_ch    = $cnf->{sep_ch}    || 20; #-- частота, с которой добавляются разделители в %
     
    #my @small_v = qw(а а а у у е е е о о ы э я и и ю);
    my @small_v = qw(a a a y y e e e o o i u u i i o);
    @small_v = @{ $cnf->{small_v} } if $cnf->{small_v};
     
    #my @small_c = qw(й ц к к н н г г з х ъ ф в п п р р л л д д ч м м т т б б ь);
    my @small_c = qw(q w r t p s d f g h j k l z x c v b n m m h g l l k r q j);
    @small_c = @{ $cnf->{small_c} } if $cnf->{small_c};
     
    #my @big = qw(У К Е Н Г Ш З Х Ф В А П Р О Л Д Ж Ч С Я М И Т Б Ю);
    my @big = qw(Y K E N G S H H F V A P R O L D Z C C Y M I T B J);
    @big = @{ $cnf->{big} } if $cnf->{big};
     
    my @end = qw(. . . . . . ! ?);
    @end = @{ $cnf->{end} } if $cnf->{end};
    my @sep = (',', ',', ',');
    @sep = @{ $cnf->{sep} } if $cnf->{sep};

    my $template;
    my $quotation = random($min_q, $max_q);
    #-- Предложения
    for (0..$quotation)
    {
        my $words = random($min_w, $max_w);
        $template .= 2; #-- Заглавная буква в начале предложения
        #-- Слова
        for (my $i = 0; $i <= $words; $i++)
        {
            #-- Буквы
            my $len_w = int(random($min_len_w, $max_len_w) / 2);
            for (0..$len_w)
            {
                $template .= (random(0, 100) < 20 ? 01 : 10);
            }
            #-- Запятая
            if (random(0, 100) < $sep_ch and $i != $words)
            {
                $template .= 4;
            }
            $template .= " "; #-- Пробел после слова
        }
        #-- Удаляем пробел в конце предложения
        chop $template;
        $template .= "3 "; #-- и ставит точку
    }
    my %m = (0 => \@small_v, 1 => \@small_c, 2 => \@big, 3 => \@end, 4 => \@sep);
    for (keys %m)
    {
        my @dict = @{ $m{$_} };
        while ($template =~ s/$_/$dict[rand(scalar @dict)]/) {}; 
    }
    return $template;
}
1;
