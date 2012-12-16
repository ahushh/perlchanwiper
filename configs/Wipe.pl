use utf8;
#------------------------------------------------------------------------------------------------------------
# FORM SETTINGS
#------------------------------------------------------------------------------------------------------------
my $post_cnf =  {
    #-- при указании ссылки на список оттуда будет взято случайное значение
    #-- например: thread     => [1,3,4,5] #-- ответ в случайный тред из заданных
    board      => 'b',
    thread     => 0,
    email      => "",
    name       => "",
    subject    => "",
    password   => "fNfR31",
};

#------------------------------------------------------------------------------------------------------------
# WATCHERS
#------------------------------------------------------------------------------------------------------------
#-- ответ в тред из найденных на страницах
#-- !! тред и страницы качаются БЕЗ ПРОКСИ
#-- впрочем, прокси можно задать вручную ниже, заменив http://no_proxy
my $w_target_cnf = { #-- текущая конфигурация: берутся все треды со страниц 0-4
                    interval  => 60*3,  #-- интервал обновления списка постов
                    #-- найденные номера постов будут присвоены $post_cnf{thread}
                    board     => 'b',   #-- доска, на которой искать треды
                    take      => 'all', #-- all - все посты, random - случайный, last - последний

                    threads => {
                                # post_limit => 300,  #-- TODO
                                # regexp  => '',      #-- фильтровать по регэкспу
                                # regexp  => '<blockquote><div class="postmessage">(\s+)?</div></blockquote>', # посты без текста
                                pages   => [0],    #-- на каких страницах искать треды, в которые нужно отвечать
                                include => 1,         #-- использовать ID найденные треды или нет
                                # in_text => '',      #-- искать номера постов в тексте треда по регэкспу;в вайпе бесполезно
                               },
                    # replies => {
                    #     include => 1,
                    #     threads => 'found', #-- искать в уже найденных тредах (см. выше)
                    #     threads => [1199],  #-- задать номер тредов вручную
                    #     regexp  => '',      #-- филтровать по регэкспуn
                    #     in_text => '&gt;&gt;/b/(?<post>\d+)', #-- искать номера постов в тексте ответа по регэкспу; в вайпе бесполезно
                    # },
                   };

my $w_target_cb = sub
{
    use Coro;
    my ($self, $conf, $queue) = @_;
    async { #-- Refresh the thread list
        use PCW::Core::Utils qw/get_posts_ids/;
        my $coro = $Coro::current;
        $coro->desc('custom-watcher');
        my @posts = get_posts_ids($self->{engine}, "http://no_proxy", $conf);
        $self->{conf}{post_cnf}{thread} = \@posts;
    };
    cede;
};

#------------------------------------------------------------------------------------------------------------
#-- вывод количества запущенных и находящихся в очереди тредов
my $w_coros_cb = sub
{
    use Coro;
    my ($self, $conf, $queue) = @_;
    async {
        my $coro = $Coro::current;
        $coro->desc('custom-watcher');

        my @get_coro      = grep { $_->desc eq 'get'     } Coro::State::list;
        my @prepare_coro  = grep { $_->desc eq 'prepare' } Coro::State::list;
        my @post_coro     = grep { $_->desc eq 'post'    } Coro::State::list;
        my @sleep_coro    = grep { $_->desc eq 'sleeping'} Coro::State::list;

        $self->{log}->msg($conf{loglevel}, sprintf "run: %d captcha, %d sleeping, %d post, %d prepare coros.",
            scalar @get_coro, scalar @sleep_coro, scalar @post_coro, scalar @prepare_coro);
        $self->{log}->msg($conf{loglevel}, sprintf "queue: %d captcha, %d post, %d prepare coros.",
            $queue->{get}->size, $queue->{post}->size, $queue->{prepare}->size);
    };
    cede;
};

#------------------------------------------------------------------------------------------------------------
# MAIN CONFIG
#------------------------------------------------------------------------------------------------------------
our %mode_config = (
    post_cnf          => $post_cnf,
    get_timeout       => 99 ,     #-- таймаут на получение капчи в секундах
    prepare_timeout   => 330 ,    #-- ... на получение капчи, создание контента и т.д.
    post_timeout      => 320,     #-- ... на создание поста
    save_captcha      => '',      #-- перемещать удачно распознанную капчу в заданный каталог, а не удалять
                                  #   имя файла имеет вид: [текст капчи]--[time stamp].[расширение]
    post_limit        => 0,       #-- после успешного создания N постов прервать вайп. 0 - отключить
    send              => {
        mode          =>  5,      #-- 0 - постинг сразу после получения капчи
                                  #   1 - дожидаться ввода остальных капч и отправлять все сообщения одновременно
                                  #   2 - дожидаться ввода caps_accum штук капч и отправлять эти сообщения одновременно
                                  #   3 - аналогично 1, только после одного "залпа" перключается в 0
                                  #   4 - аналогично 2, только после одного "залпа" перключается в 0
                                  #   5 - ждать ручного подтверждения отправки постов (только через веб-интерфейс)
        wait_for_all  =>  2,      #-- 0 - скачивать и распознавать капчу во время массового постинга
                                  #-- 1 - скачивать капчу, но не распознавать
                                  #-- 2 - не скачивать и не распознавать - ждать отправки всех постов
        caps_accum    => 170,
    },
    max_pst_thrs      => 200,     #-- максимальное количество одновременно запущенных потоков с созданием постов
    max_cap_thrs      => 20 ,     #-- ...с получением капчи
    max_prp_thrs      => 5  ,     #-- ...с распознаванием, создание контента, и т.д.
    wcap_retry        => 1,       #-- пытаться отправить пост повторно, если капча была введена неправильно
    loop              => 1,       #-- повторно постить с хороших прокси - зациклить вайп
    flood_limit       => 60*30,   #-- задержка в секундах перед повторной отправкой поста
    get_attempts      => 2,       #-- сколько раз пробовать скачать капчу, прежде чем считать прокси плохой
    post_attempts     => 5,       #-- ... отправить пост повторно при ошибках timeout/net error/unknown error; пока что игнорирует max_post_thrs
    on_spot_retrying  => 1,       #-- 1 - отправлять пост повторно сразу же после ошибки. 0 - добавлять в очередь
    prepare_attempts  => 3,       #-- ... распознать капчу
    autoexit          => 0,       #-- завершать программу, если нет запущенных или стоящих в очереди прокси; плохо дружит с вотчерами
    speed             => 'minute',#-- единицы измерения скорости постинга (second/minute/hour)
    watchers          => {        #-- кастомные вотчеры
                          target => {  #-- ответ в тред из найденных на страницах
                                     cb       => $w_target_cb,
                                     after    => $w_target_cnf->{interval},
                                     interval => $w_target_cnf->{interval},
                                     conf     => $w_target_cnf,
                                     on_start => 1,       #-- 1 - выполнять ф-ю перед стартом
                                                          #   2 - выполнить ф-ю только перед стартом и не инициализировать
                                                          #   0 - выполнять функцию во время старта
                                     type     => 'timer', #-- тип вотчера, пока только AnyEvent->timer
                                     enable   => 0,       #-- 1 - включить, 0 - отключить
                                    },
                          coros  => { #-- вывод количества запущенных и находящихся в очереди тредов
                                     cb       => $w_coros_cb,
                                     after    => 15,
                                     interval => 10,
                                     conf     => { loglevel => 1 },
                                     on_start => 0,       #-- 1 - выполнять ф-ю перед стартом
                                                          #   2 - выполнить ф-ю только перед стартом и не инициализировать
                                                          #   0 - выполнять функцию во время старта
                                     type     => 'timer', #-- тип вотчера, пока только AnyEvent->timer
                                     enable   => 1,       #-- 1 - включить, 0 - отключить
                                    },
                         },
);
