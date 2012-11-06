use utf8;
#------------------------------------------------------------------------------------------------------------
# WATCHERS
#------------------------------------------------------------------------------------------------------------
#-- вывод количества запущенных и находящихся в очереди тредов
my $w_coros_cb = sub
{
    use Coro;
    my ($self, $conf, $queue) = @_;
    async {
        my $coro = $Coro::current;
        $coro->desc('custom-watcher');

        my @coros = grep { $_->desc eq 'check' } Coro::State::list;
        $self->{log}->msg($conf->{loglevel}, sprintf "run: %d; queue: %d", scalar(@coros), $queue->{main}->size);
    };
    cede;
};

#------------------------------------------------------------------------------------------------------------
# PROXY CHECKER SETTINGS
#------------------------------------------------------------------------------------------------------------
our %mode_config = (
    #-- Настройки постинга. В общем, похуй на эти настройки.
    post_cnf => {
        board      => 'b',
        thread     => 0,
        email      => "",
        name       => "",
        subject    => "",
        password   => "fNfR3",
    },
    max_thrs   => 50, #-- максимальное колличество запущенных потоков
    timeout    => 120,
    save       => 'proxy/my/0chan', #-- сохранять хорошие прокси в файл; если не указано, прокси печаются при выходе
    watchers   =>
    {
        coros  => { #-- вывод количества запущенных и находящихся в очереди тредов
            cb       => $w_coros_cb,
            after    => 0,
            interval => 5,
            conf     => { loglevel => 1 },
            on_start => 1,       #-- 1 - выполнять ф-ю перед стартом
                                 #   2 - выполнить ф-ю только перед стартом и не инициализировать
                                 #   0 - выполнять функцию во время старта
            type     => 'timer', #-- тип вотчера, пока только AnyEvent->timer
            enable   => 1,       #-- 1 - включить, 0 - отключить
        },
    },
);
