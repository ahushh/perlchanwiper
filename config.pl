use strict;

#------------------------------------------------------------------------------------------------------------
# MESSSAGE SETTINGS
#------------------------------------------------------------------------------------------------------------
our $msg = {
    #-- !!!! Постинг НЕ ASCII-символов на нульчане не поддерживается.
    #--------------------------------------------------------------------------------------------------------
    #--- Подстановка
    #-- %unixtime%   — будет заменено текущим timestamp
    #-- %date%       — ... на строку с датой
    #-- %XrandY%     — ... на случайное целое числов в диапазоне от X до Y
    #-- @~command~@  — ... на результат выполенения внешней команды 'command'
    #--- Подстановка с параметрами
    #-- #delirium#   — сгенерированный бред
    #-- #string#     — чтение файла построчно
    #-- #boundary#   — чтение файла блоками
    #-------------------------------------------------------------------------------------------------------
    # text => "[code]#boundary#[/code]]",
    # text => "bump\n%date%",
    # text => '@~fortune psalms bible~@',
    text => '%unixtime%',
    text => '',
    #-------------------------------------------------------------------------------------------------------
    #-- #delirium# config
    delirium => {
        # q - предложение; w - слово; c - символ;
        # small_v - строчные гласные
        # small_c - строчные согласные
        #min_len_w => 0,
        #max_len_w => 0,
        #min_w     => 0,
        #max_w     => 0,
        min_q     => 20,
        max_q     => 70,
        #sep_ch    => 0,  #-- частота, с которой добавляются разделители в %
        small_v    => [qw(a a a y y e e e o o i u u i i o)],
        small_c    => [qw(q w r t p s d f g h j k l z x c v b n m m h g l l k r q j)],
        big        => [qw(Y K E N G S H H F V A P R O L D Z C C Y M I T B J)],
        end        => [".\n"],
        #sep       => [],  #-- разделители слов
    },
    #-------------------------------------------------------------------------------------------------------
    #-- #boundary# config
    boundary => {
        boundary => "----",                  #-- разделитель блоков текста. "----" по умолчанию
        order    => 'random',                #-- порядок считывания блоков (normal - по порядку; random - случайно)
        path     => "$ENV{HOME}/rm/desu/ascii",   #-- путь к файлу
    },
    #-------------------------------------------------------------------------------------------------------
    #-- #string# config
    string => {
        order    => 'random',                #-- см. выше
        num_str  => 15,                       #-- количество счтиывемых строк за раз
        path     => "$ENV{HOME}/cuw",   #-- путь к файлу
    },
};

#------------------------------------------------------------------------------------------------------------
# IMAGE SETTINGS
#------------------------------------------------------------------------------------------------------------
my $img_altering = {
    #-------------------------------------------------------------------------------------------------------
    #-- addrand mode
    #-- Дописывать в файл случайные числа
    mode        => 'addrand',
    number_nums => 50,                   #-- количество дописываемых чисел
    #-------------------------------------------------------------------------------------------------------
    #-- resize mode
    #-- Изменять разрешение картинки
    #-- необходима программа convert
    #-- работает весьма медленно
    #mode        => 'resize',
    #convert     => '/usr/bin/convert',  #-- путь до программы
    #args        => '-negate',                 #-- дополнительные аргуметны
    #min         => 70,                  #-- минмальный размер от исходного в %
    #max         => 140,                  #-- максимальный размер
    #-------------------------------------------------------------------------------------------------------
    #-- convert mode
    #-- Кастомный convert без изменения разрешения
    #-- необходима программа convert
    #-- работает весьма медленно
    #mode        => 'convert',
    #convert     => '/usr/bin/convert',  #-- путь до программы
    #args        => '-negate',                 #-- аргуметны
    #args        => '-fill red -pointsize 20 -draw "text 100,100 \'ALL HAIL DOLLCHAN\'"',
};

our $img = {
    #-------------------------------------------------------------------------------------------------------
    #-- no mode
    #-- Без изображения
    mode     => 'no',
    #-------------------------------------------------------------------------------------------------------
    #-- rand mode
    #-- Сгенерировать случайное изображение
    #mode     => 'rand',
    #args     => {},                    #-- см. документацию к модулю Data::Random, метод rand_image
    #-------------------------------------------------------------------------------------------------------
    #-- single mode
    #-- Постить один указанный файл
    # mode     => 'single',
    path     => "$ENV{HOME}/rm/desu/desutraction.jpg",    #-- пути к файлу
    #-------------------------------------------------------------------------------------------------------
    #-- dir mode
    #-- Постить файлы из каталогов
    #mode     => 'dir',
    #order    => 'random',               #-- random - перемешать файлы; normal - брать по порядку
    #path     => ["$ENV{HOME}/rm/desu"],    #-- пути к файлу
    #types    => ['jpg', 'jpeg', 'gif', 'png'],    #-- резрешенные к загрузки типы файлов
    #-------------------------------------------------------------------------------------------------------
    #-- common options
    max_size => 350,                   #-- ограничение на размер файла в кб. Указывать ВСЕГДА.
    altering => $img_altering           #-- обход запрета на повтор картинок
};

#------------------------------------------------------------------------------------------------------------
# VIDEo SETTINGS. ONLY FOR KUSABA CHANS
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
    #-- Брать ID видео из файлы
    #-- ID должны разделяться пробелами/переносами строк
    # mode     => 'file',
    order    => 'normal',        #-- см. где-то выше
    path     => "$ENV{HOME}/vid",
    #-------------------------------------------------------------------------------------------------------
    #-- download mode
    #-- Искать видео на соответствующем видеохостинге
    mode     => 'download',
    save     => "$ENV{HOME}/youtube", #-- сохранить найденные id видео в файл, разделяются пробелом
    order    => 'random',   #-- см. где-то выше
    pages    => 30,       #-- Колличество страниц, с которых будут взяты видео
    search   => ['suiseiseki', 'rozen+maiden+desu'], #-- Поисковые запросы. Пробелы заменять на символ +
};

#------------------------------------------------------------------------------------------------------------
# CAPTCHA SETTINGS
#------------------------------------------------------------------------------------------------------------
#-- Распознавание капчи
our $captcha_decode = {
    #-------------------------------------------------------------------------------------------------------
    #-- antigate mode
    # mode   => 'antigate',
    # key    => 'bdc525daac2c1c1a9b55a8cfaaf79792',
    # opt    => {},  #-- см. документацию к модулю WebService::Antigate
    #-------------------------------------------------------------------------------------------------------
    #-- captchabot mode
    #mode   => 'captchabot',
    #key    => '202ed5073f6cd7fad6ef5d2431a96ec2',
    opt    => {},  #-- см. документацию к модулю WebService::Antigate
    #-------------------------------------------------------------------------------------------------------
    #-- hand mode
    #-- Ручной ввод капчи.
    # mode   => 'hand',
    # imgv   => '/usr/bin/feh',     #-- путь до программы просмотра изображений
    # arg    => '-d --geometry 400x300 -Z', #-- аргументы
    #-- gui hand mode
    #-- Ручной ввод капчи через GUI.
    #-- Необходим Gtk2
    #-- Работает криво, вылетает. Лучше не использовать
    # mode   => 'guihand',
    #-- tesseract OCR
    #-- Необходим convert (пакет ImageMagick) и сам tesseract
    mode => 'tesseract',
};
