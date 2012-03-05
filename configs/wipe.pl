#------------------------------------------------------------------------------------------------------------
# WIPE SETTINGS
#------------------------------------------------------------------------------------------------------------
my $post_cnf =  {
    board      => 'b',
    thread     => 0,               #-- Номер искомого треда или 0 для вайпа доски
    email      => "sage",
    name       => "",
    subject    => "",
    password   => "fNfR3",
};

our %mode_config = (
    msg_data          => $msg,
    img_data          => $img,
    post_cnf          => $post_cnf,
    get_timeout       => 60,      #-- таймаут на получение капчи в секундах
    prepare_timeout   => 60,     #-- ... на получение капчи, создание контента и т.д.
    post_timeout      => 60,      #-- ... на создание поста
    save_captcha      => 1,       #-- перемещать удачно распознанную капчу в каталог ./captcha, а не удалять
                                  #   имя файла имеет вид: [текст капчи]--[time stamp].[расширение]
    post_limit        => 2,      #-- после успешного создания N постов прервать вайп
    salvo             => 0,       #-- дожидаться ввода остальных капч и отправлять все сообщения одновременно
    max_pst_thrs      => 2,       #-- максимальное колличество одновременно запущенных потоков с созданием постов
    max_cap_thrs      => 2,       #-- ...с получением капчи
    max_prp_thrs      => 2,       #-- ...с распознаванием, создание контента, и т.д.
    loop              => 0,       #-- повторно использовать прокси, с которых удачно отправился пост
    delay             => 0,       #-- задержка перед отправкой поста
    proxy_attempts    => 1,       #-- НЕ ПРОВЕРЯЛОСЬ TODO
);
 
