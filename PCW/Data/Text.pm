package PCW::Data::Text;

use v5.12;
use utf8;
use Carp qw/croak/;
use Moo;
use autodie;

has 'text_list' => (
    is      => 'rw',
    default => sub { [] },
);

has 'post_list' => (
    is      => 'rw',
    default => sub { {} },
);

has 'loaded' => (
    is      => 'rw',
    default => sub { 0 },
);

#------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------
use List::Util       qw/shuffle/;
use Data::Random     qw/rand_set/;
use PCW::Core::Utils qw/random took readfile get_posts_bodies/;

use Coro;
our $lock = Coro::Semaphore->new;
#------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------
sub fetch
{
    my ($self, $engine, $task, $msg_conf) = @_;
    return if defined $task->{test};
    $self->load($engine,$task,$msg_conf) unless $self->loaded;
    my $text = $msg_conf->{text};

    $text =~ s/#delirium#/delirium_msg($self, $engine, $task, $msg_conf->{delirium});/eg;
    $text =~ s/#delimeter#/delimeter_msg($self, $engine, $task, $msg_conf->{delimeter});/eg;
    $text =~ s/#post#/post_msg($self, $engine, $task, $msg_conf->{post});/eg;

    my $after = $msg_conf->{after} || sub { $_[0] };
    $text = &$after(_interpolate($text, $task));
    $msg_conf->{maxlen} ? substr($text, 0, $msg_conf->{maxlen}) : $text;
}

sub load
{
    my ($self, $engine, $task, $msg_conf) = @_;
    $lock->down;
    if ($msg_conf->{text} =~ /delimeter/)
    {
        my $delimeter = $msg_conf->{delimeter}{delimeter} || '----';
        $self->post_list = [ split /$delimeter/, readfile($msg_conf->{path}, 'utf8') ];
        $engine->log->msg('DATA_LOADED', "loaded with ". scalar(@{$self->text_list}) ." pieces of text.");
        $msg_conf->{loaded} = 1;
    }
    elsif ($msg_conf->{text} =~ /post/)
    {
        warn "Not implemented yet";
    }
    $lock->up;
}

#------------------------------------------------------------------------------------------------
sub _interpolate
{
    my ($text, $task) = @_;
    $text =~ s/%captcha%/$task->{captcha_text};/eg;
    $text =~ s/%proxy%/$task->{proxy};/eg;
    $text =~ s/%unixtime%/time;/eg;
    $text =~ s/%date%/scalar(localtime(time));/eg;
    $text =~ s/%(\d+)rand(\d+)%/random($1, $2);/eg;
    $text =~ s/@~(.+)~@/`$1`;/eg;
    $text =~ s/\r//g;

    return $text;
}

#------------------------------------------------------------------------------------------------
# Internal functions
#------------------------------------------------------------------------------------------------
sub post_msg
{
    my ($self, $engine, $task, $msg_conf) = @_;
    # my $take = $msg_conf->{take};
    # my $c = async { &$take($engine, $task, $msg_conf, \%posts) };
    # return $c->join();
    warn "Not implemented yet";
}

sub delimeter_msg
{
    my ($self, $engine, $task, $delimeter_conf) = @_;
    state $i = 0;

    my $msg;
    if ($delimeter_conf->{order} eq 'random')
    {
        $msg = ${ rand_set(set => $self->text_list ) };
    }
    else
    {
        my @texts = @{ $self->text_list };
        $i = 0 if ($i >= scalar @texts);
        $msg = $texts[$i++];
    }
    return $msg;
}

sub delirium_msg
{
    my ($self, undef, $task, $cnf) = @_;
    my $min_len_w = $cnf->{min_len_w} || 3;
    my $max_len_w = $cnf->{max_len_w} || 7;
    my $min_w     = $cnf->{min_w}     || 1;
    my $max_w     = $cnf->{max_w}     || 10;
    my $min_q     = $cnf->{min_q}     || 3;
    my $max_q     = $cnf->{max_q}     || 20;
    my $sep_ch    = $cnf->{sep_ch}    || 20; #-- частота в %, с которой добавляются разделители

    my @small_v = qw/а а а у у е е е о о ы э я и и ю/;
    @small_v = @{ $cnf->{small_v} } if $cnf->{small_v};

    my @small_c = qw/й ц к к н н г г з х ъ ф в п п р р л л д д ч м м т т б б ь/;
    @small_c = @{ $cnf->{small_c} } if $cnf->{small_c};

    my @big = qw/У К Е Н Г Ш З Х Ф В А П Р О Л Д Ж Ч С Я М И Т Б Ю/;
    @big = @{ $cnf->{big} } if $cnf->{big};

    my @end = qw/. . . . . . ! ?/;
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
        #-- Удаляет пробел в конце предложения
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
