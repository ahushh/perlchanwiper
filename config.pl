use v5.12;
use utf8;
#------------------------------------------------------------------------------------------------------------
# MESSSAGE SETTINGS
#------------------------------------------------------------------------------------------------------------
our $msg = {
    #--------------------------------------------------------------------------------------------------------
    #--- Подстановка
    #-- %unixtime%   — будет заменено текущим timestamp
    #-- %date%       — ... на строку с датой
    #-- %XrandY%     — ... на случайное целое числов в диапазоне от X до Y
    #-- %captcha%    — ... на текст капчи
    #-- @~command~@  — ... на результат выполенения внешней команды 'command'
    #--- Подстановка с параметрами
    #-- #delirium#   — сгенерированный бред
    #-- #string#     — чтение файла построчно
    #-- #boundary#   — чтение файла блоками
    #-- #post#       — брать данные из текста скаченных постов
    #-------------------------------------------------------------------------------------------------------
    # text => "[code]#boundary#[/code]]",
    # text => "bump\n%date%",
    # text => '@~fortune psalms bible~@',
    # text => '%unixtime%',
    # text => ">>#post#\n>>#post#\n",
    # text => '#delirium#',
    # text => '#post#',
      text => '@~fortune psalms bible~@',
    # text => "bump %date%\n@~fortune psalms bible~@",
    # after => sub { $_=shift; s/--|\d+:\d+//g; s/\n/ /g; $_  },
    #-------------------------------------------------------------------------------------------------------
    #-- #post# config
    post  => {
        board  => 'b',          #-- если не указано — текущая борда
        thread => 0,           #-- из какого треда брать номера постов; если 0 - текущий вайпаемый тред
        # thread => "$ENV{HOME}/1.html", #-- также можно указать путь до html-файла
        update => 100,           #-- интервал обновления списка постов; 0 - отключить
        # take   => sub {        #-- функция, которая извлекает нужные данные из поста. в данном случае - ID поста
        #     use Data::Random     qw/rand_set/;
        #     my ($engine, $task, $data, $replies) = @_;
        #     my @ids = keys %$replies;
        #     return ( @ids ? ${ rand_set(set => \@ids) } : '' );
        # },
        take   => sub { #-- текст постов
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
        # min_q     => 1,
        # max_q     => 5,
        # sep_ch    => 0,  #-- частота, с которой добавляются разделители в %
        small_v    => [qw(a a a y y e e e o o i u u i i o)],
        small_c    => [qw(q w r t p s d f g h j k l z x c v b n m m h g l l k r q j)],
        big        => [qw(Y K E N G S H H F V A P R O L D Z C C Y M I T B J)],
        # end        => [".\n"],
        # sep       => [],  #-- разделители слов
    },
    #-------------------------------------------------------------------------------------------------------
    #-- #boundary# config
    boundary => {
        boundary => "----",                  #-- разделитель блоков текста. "----" по умолчанию
        order    => 'random',                #-- порядок считывания блоков (normal - по порядку; random - случайно)
        path     => "$ENV{HOME}/",           #-- путь к файлу
    },
    #-------------------------------------------------------------------------------------------------------
    #-- #string# config
    string => {
        order    => 'random',                #-- см. выше
        num_str  => 10,                      #-- количество счтиывемых строк за раз
        path     => "$ENV{HOME}/",           #-- путь к файлу
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
    mode        => 'randnums',
    number_nums => 50,                   #-- количество дописываемых чисел
    #-------------------------------------------------------------------------------------------------------
    #-- randbytes mode
    #-- Дописывать в конец файла случайные байты
    # mode         => 'randbytes',
    # number_bytes => "%10rand700%",           #-- количество дописываемых байтов
    #-------------------------------------------------------------------------------------------------------
    #-- convert mode
    #-- необходима программа convert
    # mode        => 'convert',
    # convert     => 'convert',  #-- путь до программы; если не указано, определяется автоматически
    # Строка аргументов. Рисует текст на картинке:
    # args        => '-fill green -pointsize 30 -draw "text 50,50 \'текст на картинке\'" %source% %dest%',
    # Ресайз картинки от 10 до 200% от исходного размера
    # args        => '-resize %10rand200%% %source% %dest%',
    # Добавление в headers изображения случайной последовательности цифр
    # args        => '-set comment %%10rand100000%digits% %source% %dest%',
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
#    path     => "extra/desu.gif",    #-- путь к файлу
    #-- captcha mode
    #-- Постить изображение капчи
    # mode => 'captcha',
    #-------------------------------------------------------------------------------------------------------
    #-- dir mode
    #-- Постить файлы из каталогов
    # mode        => 'dir',
    # order       => 'random',               #-- random - перемешать файлы; normal - брать по порядку
    # path        => ["c:\\users\\user\\Desktop\\1"], #-- пути к файлу
    # regexp      => '',                   #-- фильтровать имена файлов (вместе с расширением) по регэкспам
    # recursively => 1,                    #-- искать файлы и в подпапках
    # types       => ['jpg', 'jpeg', 'gif', 'png'],    #-- резрешенные к загрузки типы файлов
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
    max_size => 500,                   #-- ограничение на размер файла в кб. 0 для отключения
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
    pages    => 20,                     #-- Колличество страниц, с которых будут взяты видео
    search   => ['Sony+Playstation+3'], #-- Поисковые запросы. Пробелы заменять на символ +
};

#------------------------------------------------------------------------------------------------------------
# CAPTCHA SETTINGS
#------------------------------------------------------------------------------------------------------------
#-- Распознавание капчи
our $captcha_decode = {
    #-------------------------------------------------------------------------------------------------------
    #-- antigate mode
     mode   => 'antigate',
     key    => 'bdc525daac2c1c1a9b55a8cfaaf79792',
     opt    => {},  #-- см. документацию к модулю WebService::Antigate
    #-------------------------------------------------------------------------------------------------------
    #-- captchabot mode
    # mode   => 'captchabot',
    # key    => '',
    # opt    => {},  #-- см. документацию к модулю WebService::Antigate
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
    #-- просто заглушка
    # mode => 'none',
    #-- tesseract OCR
    #-- Необходим convert (пакет ImageMagick) и сам tesseract
    # mode   => 'tesseract',
      after  => sub { my $_=shift; s/\s+//g; $_ }, #-- функция для дополнительно обработки разгаданного текста
    # lang   => 'eng',          #-- eng, rus, etc.
      config => 'englishletters', #-- название конфига для tesseract. см README
    # config => 'ruletters',    #-- название конфига для tesseract. см README
};
