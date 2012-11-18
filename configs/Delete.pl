use utf8;
#------------------------------------------------------------------------------------------------------------
# WATCHERS
#------------------------------------------------------------------------------------------------------------
##-- вывод количества запущенных и находящихся в очереди тредов
my $w_coros_cb = sub
{
    use Coro;
    my ($self, $conf, $queue) = @_;
    async {
        my $coro = $Coro::current;
        $coro->desc('custom-watcher');

        my @delete_coro  = grep { $_->desc eq 'delete' } Coro::State::list;
        $self->{log}->msg(4, sprintf "run: %d; queue: %d", scalar @delete_coro, $queue->{delete}->size);
    };
    cede;
};

#------------------------------------------------------------------------------------------------------------
# DELETE SETTINGS
#------------------------------------------------------------------------------------------------------------
my $find = { #-- текущая конфигурация: ищутся треды без текста на страницах 0-4
    board     => 'b',      #-- доска, на которой искать посты
    take      => 'all',    #-- all - все посты, random - случайный, last - последний
    threads   => {         #-- треды
        include => 1,      #-- удалять найденные треды, 1 - да, 0 - нет
        regexp  => '.*',      #-- фильтровать по регэкспу
        # regexp  => '<blockquote><div class="postmessage">(\s+)?</div></blockquote>', #-- треды без текста (нульчан)
        pages   => [0..4],      #-- на каких страницах искать
        # in_text => '',        #-- искать номера постов в тексте треда по регэкспу
    },
    # replies => {                    #-- ответы
    #     include => 1,               #-- удалять найденные ответы, 1 - да, 0 - нет
    #     threads => [10388824],      #-- в каких тредах искать (по id)
    #     threads => 'found',         #-- искать в уже найденных тредах (см. выше)
    #     regexp  => '✡',             #-- фильтровать по регэкспу
    #     in_text => '>>/b/(?<post>\d+)',     #-- искать номера постов в тексте ответа по регэкспу
    # },
};
our %mode_config = (
    ids            => [],      #-- вручную задать номера удаляемых постов/тредов
    find           => $find,   #-- или искать по регэкспам на доске; закомментировать для отключения
    password       => "fNfR31",
    deletepost     => "Удалить", #-- Обычно "Delete" или "Удалить"
    board          => 'b',     #-- доска, с которой удалять сообщения
    max_del_thrs   => 1,       #-- максимально количество запущенных потоков
    delete_timeout => 60,      #-- таймаут
    watchers       =>
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

