use utf8;
#------------------------------------------------------------------------------------------------------------
# FORM SETTINGS
#------------------------------------------------------------------------------------------------------------
my $post_cnf =  {
    #-- при указании ссылки на список оттуда будет взято случайное значение
    #-- например: thread     => [1,3,4,5] #-- ответ в случайный тред из заданных
    board      => 'b',
    thread     => 77949,
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
my $w_target_cnf = { 
                    interval  => 60*3,  #-- интервал обновления списка постов
                    #-- найденные номера постов будут присвоены $post_cnf{thread}
                    board     => 'b',   #-- доска, на которой искать треды
                    take      => 'all', #-- all - все посты, random - случайный, last - последний

                    threads => {
                                #post_limit => 300,  #-- TODO
                                #regexp  => '311',   #-- фильтровать по регэкспу
                                #regexp  => '<blockquote><div class="postmessage">(\s+)?</div></blockquote>',
                                pages   => [0], #-- на каких страницах искать треды, в которые нужно отвечать
                                include => 1,
                                #in_text => '',     #-- искать номера постов в тексте треда по регэкспу
                               },
                    # replies => {
                    #     include => 1,
                    #     #threads => 'found', #-- искать в уже найденных тредах (см. выше)
                    #     threads => [1199], #-- искать в уже найденных тредах (см. выше)
                    #     regexp  => '',    #-- филтровать по регэкспу
                    #     in_text => '&gt;&gt;/b/(?<post>\d+)',     #-- искать номера постов в тексте ответа по регэкспу
                    #},

                   };

my $w_target_cb = sub
{
    use Coro;
    my ($self, $conf, $queue) = @_;
    async { #-- Refresh the thread list
        my $coro = $Coro::current;
        $coro->desc('custom-watcher');
        my @posts = $self->get_posts_by_regexp("http://no_proxy", $conf);
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
    get_timeout       => 90,      #-- таймаут на получение капчи в секундах
    prepare_timeout   => 400,      #-- ... на получение капчи, создание контента и т.д.
    post_timeout      => 180,     #-- ... на создание поста
    save_captcha      => 0,       #-- перемещать удачно распознанную капчу в каталог ./captcha, а не удалять
                                  #   имя файла имеет вид: [текст капчи]--[time stamp].[расширение]
    post_limit        => 0,       #-- после успешного создания N постов прервать вайп. 0 - отключить
    salvo             => 0,       #-- дожидаться ввода остальных капч и отправлять все сообщения одновременно
    #salvoX            => 1,       #-- дожидаться ввода $max_pst_thrs штук капч и отправлять эти сообщения одновременно
    max_pst_thrs      => 10,     #-- максимальное колличество одновременно запущенных потоков с созданием постов
    max_cap_thrs      => 70,     #-- ...с получением капчи
    max_prp_thrs      => 10,     #-- ...с распознаванием, создание контента, и т.д.
    wcap_retry        => 1,       #-- пытаться отправить пост повторно, если капча была введена неправильно
    loop              => 1,       #-- повторно постить с хороших прокси - зациклить вайп
    flood_limit       => 60*1,    #-- задержка в секундах перед повторной отправкой поста
    proxy_attempts    => 5,       #-- сколько раз пробовать скачать капчу или отправить пост, прежде чем считать прокси плохой
    autoexit          => 1,       #-- завершать программу, если нет запущенных или стоящих в очереди прокси
    speed             => 'minute', #-- единицы измерения скорости постинга (second/minute/hour)
    watchers          => {        #-- кастомные вотчеры; для отключению закомментировать
                          # target => {  #-- ответ в тред из найденных на страницах
                          #            cb       => $w_target_cb,
                          #            after    => $w_target_cnf->{interval},
                          #            interval => $w_target_cnf->{interval},
                          #            conf     => $w_target_cnf,
                          #            on_start => 1,       #-- 1 - выполнять ф-ю перед стартом
                          #                                 #   2 - выполнить ф-ю только перед стартом и не инициализировать
                          #            type     => 'timer', #-- тип вотчера, пока только AnyEvent->timer
                          #           },
                          coros  => { #-- вывод количества запущенных и находящихся в очереди тредов
                                     cb       => $w_coros_cb,
                                     after    => 15,
                                     interval => 15,
                                     conf     => { loglevel => 1 },
                                     on_start => 0,       #-- 1 - выполнять ф-ю перед стартом
                                                          #   2 - выполнить ф-ю только перед стартом и не инициализировать
                                     type     => 'timer', #-- тип вотчера, пока только AnyEvent->timer
                                    },
                         },
);
