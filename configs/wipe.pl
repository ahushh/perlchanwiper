#------------------------------------------------------------------------------------------------------------
# WIPE SETTINGS
#------------------------------------------------------------------------------------------------------------
my $post_cnf =  {
    board      => 'b',
    thread     => 0,
    thread     => 9997029,               #-- Номер искомого треда или 0 для вайпа доски
    email      => "",
    name       => "",
    subject    => "",
    password   => "fNfR3",
};

our %mode_config = (
    msg_data          => $msg,
    img_data          => $img,
    post_cnf          => $post_cnf,
    get_timeout       => 160,      #-- таймаут на получение капчи в секундах
    prepare_timeout   => 160,     #-- ... на получение капчи, создание контента и т.д.
    post_timeout      => 360,      #-- ... на создание поста
    save_captcha      => 0,       #-- перемещать удачно распознанную капчу в каталог ./captcha, а не удалять
                                  #   имя файла имеет вид: [текст капчи]--[time stamp].[расширение]
    post_limit        => 0,      #-- после успешного создания N постов прервать вайп
    salvo             => 0,       #-- дожидаться ввода остальных капч и отправлять все сообщения одновременно
    max_pst_thrs      => 100,       #-- максимальное колличество одновременно запущенных потоков с созданием постов
    max_cap_thrs      => 200,       #-- ...с получением капчи
    max_prp_thrs      => 100,       #-- ...с распознаванием, создание контента, и т.д.
    loop              => 1,       #-- повторно использовать прокси, с которых удачно отправился пост
    flood_limit       => 2,       #-- 
    proxy_attempts    => 3,       #-- НЕ ПРОВЕРЯЛОСЬ TODO
);
 
