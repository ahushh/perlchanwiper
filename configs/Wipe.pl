use utf8;
#------------------------------------------------------------------------------------------------------------
# WIPE SETTINGS
#------------------------------------------------------------------------------------------------------------
my $post_cnf =  {
    #-- при указании ссылки на список оттуда будет взято случайное значение
    #-- например: thread     => [1,3,4,5] #-- ответ в случайный тред из заданных
    board      => 'b',
    thread     => 0,
    thread     => 10039960,               #-- Номера тредов или 0 для вайпа доски
    email      => "",
    name       => "",
    subject    => "",
    password   => "fNfR31",
};

#-- ответ в случайный тред из найденных
#-- !! тред и страницы качаются БЕЗ ПРОКСИ
my $random_reply = {
                    #-- найденные номера постов будут присвоены $post_cnf{thread}
                    board    => 'b',   #-- доска, на которой искать треды
                    interval => 60*5,  #-- интервал обновления списка постов
                    threads => {
                                regexp  => '.*',   #-- фильтровать по регэкспу
                                pages   => [0..2], #-- на каких страницах искать треды, в которые нужно отвечать
                                include => 1,
                               },
                   };
our %mode_config = (
    post_cnf          => $post_cnf,
    random_reply      => $random_reply, #-- закомментировать для отключения
    get_timeout       => 60,     #-- таймаут на получение капчи в секундах
    prepare_timeout   => 60,      #-- ... на получение капчи, создание контента и т.д.
    post_timeout      => 60,     #-- ... на создание поста
    save_captcha      => 0,       #-- перемещать удачно распознанную капчу в каталог ./captcha, а не удалять
                                  #   имя файла имеет вид: [текст капчи]--[time stamp].[расширение]
    post_limit        => 0,       #-- после успешного создания N постов прервать вайп. 0 - отключить
    salvo             => 0,       #-- дожидаться ввода остальных капч и отправлять все сообщения одновременно
    max_pst_thrs      => 200,      #-- максимальное колличество одновременно запущенных потоков с созданием постов
    max_cap_thrs      => 200,      #-- ...с получением капчи
    max_prp_thrs      => 200,      #-- ...с распознаванием, создание контента, и т.д.
    wcap_retry        => 1,       #-- пытаться отправить пост повторно, если капча была введена неправильно
    loop              => 1,       #-- повторно постить с хороших прокси - зациклить вайп
    flood_limit       => 60*1,    #-- задержка в секундах перед повторной отправкой поста
    proxy_attempts    => 1,       #-- сколько раз пробовать скачать капчу или отправить пост, прежде чем считать прокси плохой
);
