use v5.12;
use utf8;
#------------------------------------------------------------------------------------------------------------
# LOGGING LEVELS
#------------------------------------------------------------------------------------------------------------
our $log_settings = {
    #-- OCR
    OCR_ERROR          => 2,
    OCR_ABUSE_SUCCESS  => 3,
    OCR_ABUSE_ERROR    => 2,
    #-- DATA
    DATA_SEEK          => 3, #-- поиск тредов/постов/...
    DATA_LOADING       => 3, #-- начало загрузки ...
    DATA_LOADED        => 2, #-- конец загрузки
    DATA_MATCHED       => 3, #-- сколько совпало по регэкспу постов/тредов
    DATA_FOUND         => 3, #-- сколько тредов/постов/найденно
    DATA_FOUND_ALL     => 2, #-- сколько найденно всего
    DATA_TAKE_IDS      => 3, #-- какой ID треда взят и сколько
    DATA_VIDEO_SAVED   => 2, #-- куда сохранены видео
    #-- MODES IN GENERAL
    MODE_TIEMOUT       => 2,
    MODE_STATE         => 1, #-- start/stop/init
    MODE_CB            => 4, #-- дебаг
    MODE_SLEEP         => 3,
    #-- AUTOBUMP
    AB_NEEDS_BUMP      => 1,
    AB_NEEDS_NO_BUMP   => 1,
    AB_CHECKING        => 1,
    #-- DELETE
    DEL_SHOW_PROXY     => 1,
    #-- PROXY CHECKER
    PC_SAVE_PROXIES    => 1,
    #-- WIPE
    WIPE_STRIKE        => 1,
    GET_CB             => 4, #-- дебаг
    PREP_CB            => 4, #-- дебаг
    WIPE_CB            => 2, #-- дебаг
    #-- ENGINES
    ENGN_GET_CAP       => 3, #-- успешное получение капчи
    ENGN_GET_ERR_CAP   => 2, #-- ошибка ...
    ENGN_PRP_CAP       => 3, #-- успешное распознование капчи
    ENGN_PRP_ERR_CAP   => 2, #-- ошибка ...
    ENGN_POST          => 1, #-- успешно отправлен пост
    ENGN_POST_ERR      => 1, #-- ошибка при отправке
    ENGN_DELETE        => 1, #-- успешно удален пост
    ENGN_DELETE_ERR    => 1, #-- не удален
    ENGN_CHECK         => 1, #-- хорошая прокси
    ENGN_CHECK_ERR     => 1, #-- плохая прокси
    #-- EFG's KUSABA
    ENGN_EFG_MM        => 3, #-- вывод вычисленного mm
    #-- всякие важные ошибки
    ERROR              => 1,
    DEBUG              => 1,
};
#------------------------------------------------------------------------------------------------------------
# MESSSAGE SETTINGS
#------------------------------------------------------------------------------------------------------------
our $msg = {
    #--------------------------------------------------------------------------------------------------------
    #--- Подстановка
    #-- %unixtime%   — будет заменено текущим timestamp
    #-- %date%       — ... на строку с датой
    #-- %XrandY%     — ... на случайное целое число в диапазоне от X до Y
    #-- %captcha%    — ... на текст капчи
    #-- @~command~@  — ... на результат выполнения внешней команды 'command'
    #--- Подстановка с параметрами
    #-- #delirium#   — сгенерированный из слогов бред
    #-- #string#     — чтение файла построчно
    #-- #boundary#   — чтение файла блоками
    #-- #post#       — брать данные из текста скаченных постов
    #-------------------------------------------------------------------------------------------------------
      text => "[code]#boundary#[/code]\n#delirium#%proxy%",
    # text => "bump\n%date%",
    # text => '@~fortune~@',
    # text => "#post#\nhttp://2ch.hk",
    # text => '%unixtime%',
    # text => ">>#post#\n>>#post#\n",
    # text => '#delirium#',
    # text => "bump %date%\n@~fortune psalms bible~@",
    # after  => sub { $_=shift; s/--|\d+:\d+//g; s/\n/ /g; $_  },
     maxlen => 7000,                    #-- обрезать текст, если превышает заданную длину
    #-------------------------------------------------------------------------------------------------------
    #-- #post# config
    post  => {
        board  => 'b',         #-- если не указано — текущая борда
        update => 100,         #-- интервал обновления списка постов; 0 - отключить
        # posts => "$ENV{HOME}/1.html", #-- также можно указать путь до html-файла
        proxy  => 'no_proxy',  #-- если не указано - текущая прокси, с которой идет постинг
        posts => {             # конфиг функции, ищущей посты
                    board     => 'b',   #-- доска, на которой искать треды
                    threads => {
                                # regexp  => '',      #-- фильтровать по регэкспу
                                pages   => [0],    #-- на каких страницах искать треды, из которых будут взяты посты
                                number  => 3, #-- кол-во случайных тредов, из которых будут взяты посты
                                              #-- 0 - все треды, но лучше не использовать из-за возможных тормозов
                               },
                    replies => {
                        threads => 'found', #-- искать в уже найденных тредах (см. выше)
                        # threads => [1199],  #-- задать номер тредов вручную
                        regexp  => '',      #-- фильтровать по регэкспу
                    },
                 },
        # maxlen => 7900,                    #-- обрезать текст, если превышает заданную длину
        # take   => sub {        #-- функция, которая извлекает нужные данные из поста. в данном случае - ID поста
        #     use Data::Random     qw/rand_set/;
        #     my ($engine, $task, $data, $replies) = @_;
        #     my @ids = keys %$replies;
        #     return ( @ids ? ${ rand_set(set => \@ids) } : '' );
        # },
        take   => sub { #-- извлекает текст постов
            use HTML::Entities;
            use Data::Random     qw/rand_set/;
            my $html2text = sub
            {
                my $html = shift;
                decode_entities($html);
                $html =~ s!<style.+?>.*?</style>!!sg;
                $html =~ s!<script.+?>.*?</script>!!sg;
                $html =~ s/{.*?}//sg; #-- style
                $html =~ s/<!--.*?-->//sg; #-- comments
                $html =~ s/<.*?>//sg;      #-- tags
                return $html;
            };
            my ($engine, $task, $data, $replies) = @_;
            my $pattern = $engine->{html}{text_regexp};
            my @texts   = grep { s/\s//gr } map { $replies->{$_} =~ /$pattern/s; &$html2text( $+{text} =~ s|<br ?/?>|\n|gr ) } keys %$replies;
            return ( @texts ? ${ rand_set(set => \@texts) } : '' );
        },
    },
    #-- #delirium# config
    delirium => {
        #  q - предложение; w - слово; c - символ;
        #  small_v - строчные гласные
        #  small_c - строчные согласные
        # min_len_w => 0,
        # max_len_w => 0,
        # min_w     => 0,
        # max_w     => 0,
         min_q     => 1,
         max_q     => 2,
        # sep_ch    => 0,  #-- частота, с которой добавляются разделители в %
        # small_v   => [qw(a a a y y e e e o o i u u i i o)],
        # small_c   => [qw(q w r t p s d f g h j k l z x c v b n m m h g l l k r q j)],
        # big       => [qw(Y K E N G S H H F V A P R O L D Z C C Y M I T B J)],
        # end       => [".\n"],
        # sep       => [],   #-- разделители слов
        # maxlen    => 7900, #-- обрезать текст, если превышает заданную длину
    },
    #-------------------------------------------------------------------------------------------------------
    #-- #boundary# config
    boundary => {
        boundary => "----",                  #-- разделитель блоков текста. "----" по умолчанию
        order    => 'random',                #-- порядок считывания блоков (normal - по порядку; random - случайно)
        path     => "$ENV{HOME}/ахм",       #-- путь к файлу. Текст должен быть в кодировке utf8.
        maxlen   => 7000,                    #-- обрезать текст, если превышает заданную длину
    },
    #-------------------------------------------------------------------------------------------------------
    #-- #string# config
    string => {
        order    => 'random',                #-- см. выше
        num_str  => 10,                      #-- количество считываемых строк за раз
        path     => "$ENV{HOME}/",           #-- путь к файлу. Текст должен быть в кодировке utf8.
        # maxlen   => 7900,                  #-- обрезать текст, если превышает заданную длину
    },
};

#------------------------------------------------------------------------------------------------------------
# IMAGE SETTINGS
#------------------------------------------------------------------------------------------------------------
my $img_altering = {
    #-------------------------------------------------------------------------------------------------------
    # %XrandY%    — заменяется на случайное целое число в диапазоне от X до Y
    # %Xdigits%   — на X случайных цифр
    # %source%    — на путь исходного файла
    # %dest%      — на путь конечного файла
    #-- randnum mode
    #-- Дописывать в конец файла случайные цифры
    # mode        => 'randnums',
    # number_nums => 50,                   #-- количество дописываемых чисел
    #-------------------------------------------------------------------------------------------------------
    #-- randbytes mode
    #-- Дописывать в конец файла случайные байты
    mode         => 'randbytes',
    number_bytes => "%10rand700%",           #-- количество дописываемых байтов
    #-------------------------------------------------------------------------------------------------------
    #-- convert mode
    #-- необходима программа convert
    #-- медленно работает. лучше заранее наконвертить картинок, каких надо.
    # mode        => 'convert',
    # convert     => 'convert',  #-- путь до программы; если не указано, определяется автоматически
    # Строка аргументов. Рисует текст на картинке:
    # args        => '-fill green -pointsize 30 -draw "text 50,50 \'текст на картинке\'" %source% %dest%',
    # Ресайз картинки от 10 до 200% от исходного размера
    # args        => '-resize %10rand105%% %source% %dest%',
    # Добавление в headers изображения случайной последовательности цифр
    # args        => '-set comment %%10rand100000%digits% %source% %dest%',
    #-------------------------------------------------------------------------------------------------------
    #-- дописывать в конец файла заданный текст
    sign => 'Piston Wipe 2.6.8',
};

our $img = {
    #-------------------------------------------------------------------------------------------------------
    #-- no mode
    #-- Без изображения
    mode     => 'no',
    #-------------------------------------------------------------------------------------------------------
    #-- rand mode
    #-- Сгенерировать случайное изображение
    # mode     => 'rand',
    # args     => {},                    #-- см. документацию к модулю Data::Random, метод rand_image
    #-------------------------------------------------------------------------------------------------------
    #-- single mode
    #-- Постить один указанный файл
    mode     => 'single',
    path     => "extra/void.gif",    #-- путь к файлу
    # path     => "$ENV{HOME}/",
    # path     => "extra/desu.gif",
    #-- captcha mode
    #-- Постить изображение капчи
    # mode => 'captcha',
    #-------------------------------------------------------------------------------------------------------
    #-- dir mode
    #-- Постить файлы из каталогов
    # mode        => 'dir',
    # order       => 'random',               #-- random - перемешать файлы; normal - брать по порядку
    # path        => ["$ENV{HOME}/wipe"],  #-- пути к папкам
    # regexp      => 'Shinku',                   #-- фильтровать имена файлов (вместе с расширением) по регэкспам
    # recursively => 1,                    #-- искать файлы и в подпапках
    # types       => ['jpg', 'jpeg', 'gif', 'png'],    #-- разрешенные к загрузке типы файлов
    #-------------------------------------------------------------------------------------------------------
    #-- TODO: post mode
    #-- скачивать картинки из тредов и постить их
    # post  => {
    #     board  => '',       #-- если не указано — текущая борда
    #     thread => 10426106, #-- из какого треда брать номера постов; если 0 - текущий вайпаемый тред
    #     update => 0,        #-- интервал обновления списка постов; 0 - отключить
    # },
    #-------------------------------------------------------------------------------------------------------
    #-- common options
    max_size => "300Ki",                 #-- ограничение на размер файла в кб. 0 для отключения
    altering => $img_altering           #-- обход запрета на повтор картинок
};

#------------------------------------------------------------------------------------------------------------
# VIDEO SETTINGS. KUSABA BASED CHANS ONLY
#------------------------------------------------------------------------------------------------------------
our $vid = {
    #-------------------------------------------------------------------------------------------------------
    #-- Видеохостинг
    type     => 'youtube', #-- Поддерживаемые: youtube
    #-------------------------------------------------------------------------------------------------------
    #-- no mode
    #-- Без видео
    mode     => 'no',
    #-------------------------------------------------------------------------------------------------------
    #-- file mode
    #-- Брать ID видео из файла
    #-- ID должны разделяться пробелами или переносами строк
    # mode     => 'file',
    order    => 'random',        #-- см. где-то выше
    path     => "$ENV{HOME}/youtube",
    #-------------------------------------------------------------------------------------------------------
    #-- download mode
    #-- Искать видео на соответствующем видеохостинге
    # mode     => 'download',
    # save     => "$ENV{HOME}/youtube", #-- сохранить найденные id видео в файл; id разделяются пробелом
    order    => 'random',               #-- см. где-то выше
    pages    => 20,                     #-- Количество страниц, с которых будут взяты видео
    search   => ['Шопен', 'Franz Liszt', 'Wolfgang Amadeus Mozart', 'Мусоргский'],        #-- Поисковые запросы.
};

#------------------------------------------------------------------------------------------------------------
# CAPTCHA SETTINGS
#------------------------------------------------------------------------------------------------------------
#-- Распознавание капчи
our $captcha_decode = {
    #-------------------------------------------------------------------------------------------------------
    #-- функция для дополнительной обработки разгаданного текста капчи.
    #-- например для отклонения текста капчи с латиницей и цифрами. Также удаляет пробелы
    after  => sub { $_=shift; s/\s+//g; /[a-zA-Z0-9]/ ? "" : $_ }, 
    #-- antigate mode
    mode   => 'antigate',
    key    => 'bdc525daac2c1c1a9b55a8cfaaf79792',
    opt    => {
               is_russian =>   1,
               phrase     =>   0,  #-- 1 if captcha text have 2-4 words
               regsense   =>   0,  #-- 1 if that captcha text is case sensitive
               numeric    =>   0,  #-- 1 if that captcha text contains only digits, 2 if captcha text have no digits
               calc       =>   0,  #-- 1 if that digits on the captcha should be summed up
               min_len    =>   7,  #-- minimum length of the captcha text (0..20)
               max_len    =>   7,  #-- maximum length of the captcha text (0..20), 0 - no limits
              },
    #-------------------------------------------------------------------------------------------------------
    #-- captchabot mode
    # mode   => 'captchabot',
    # key    => '',
    # opt    => {},  #-- аналогично антигейту
    #-------------------------------------------------------------------------------------------------------
    #-- web mode
    #-- Ввод капчи вручную через веб-морду
     mode   => 'web',
    #-------------------------------------------------------------------------------------------------------
    #-- hand mode
    #-- Ручной ввод капчи.
    # mode   => 'hand',
    # imgv   => '/usr/bin/feh',             #-- путь до программы просмотра изображений
    # arg    => '-d --geometry 400x300 -Z', #-- аргументы
    #-- gui hand mode
    #-- Ручной ввод капчи через GUI.
    #-- Необходим Gtk2
    # mode   => 'guihand',
    #-- просто заглушка, всегда возвращающая текст "none"
    # mode => 'none',
    #-- tesseract OCR
    #-- Необходим convert (пакет ImageMagick) и сам tesseract
    # mode   => 'tesseract',
    # lang   => 'rus',            #-- eng, rus, etc.
    # config => 'englishletters', #-- название конфига для tesseract. см. README
    # config => 'ruletters',
    # psm    => undef,            #-- только для версии 3.01, см. tesseract --help
};
