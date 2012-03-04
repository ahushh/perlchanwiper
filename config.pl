use strict;
#------------------------------------------------------------------------------------------------------------
# MESSSAGE SETTINGS
#------------------------------------------------------------------------------------------------------------
our $msg = {
    #--------------------------------------------------------------------------------------------------------
    #-- no mode
    #-- Без текста
    mode     => 'no',
    #--------------------------------------------------------------------------------------------------------
    #-- single mode
    #-- Текст берется из строки
    mode     => 'single',
    text     => "sage %time%",
    #--------------------------------------------------------------------------------------------------------
    #-- boundary mode
    #-- Текст считывается из файла блоками
    #mode     => 'boundary', 
    #boundary => "----",                  #-- разделитель блоков текста
    #order    => 'normal',                #-- порядок считывания блоков (normal - по-порядку; random - случайно) 
    #path     => "$ENV{HOME}/fire.txt",   #-- путь к файлу
    #-------------------------------------------------------------------------------------------------------
    #-- string mode
    #-- Текст считывается из файла по строкам
    #mode     => 'string', 
    #order    => 'normal',                #-- см. выше
    #num_str  => 1,                       #-- количество счтиывемых строк за раз
    #path     => "$ENV{HOME}/fire.txt",   #-- путь к файлу
    #-------------------------------------------------------------------------------------------------------
    #-- delirium mode
    #-- случайный текст
    #mode     => 'delirium', 
    #min_len_w => 0,
    #max_len_w => 0,
    #min_w     => 0,
    #max_w     => 0,
    #min_q     => 0,
    #max_q     => 0,
    #sep_ch    => 0,
    #small_v   => [],
    #small_c   => [],
    #big       => [],
    #end       => [],
    #sep       => [],
    #-------------------------------------------------------------------------------------------------------
    #-- common options
    #sign     => '✡✡✡',                   #-- добавлять в конец текста "подпись"
    #sign     => '✡autobump testing✡',                   #-- добавлять в конец текста "подпись"
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
    #min         => 10,                  #-- минмальный размер от исходного в %
    #max         => 500,                  #-- максимальный размер
    #-------------------------------------------------------------------------------------------------------
    #-- convert mode
    #-- Кастомный convert
    #-- необходима программа convert
    #-- работает весьма медленно
    #mode        => 'convert',
    #convert     => '/usr/bin/convert',  #-- путь до программы
    #args        => '-negate',                 #-- аргуметны
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
    #args     => {},                    #-- см. Data::Random rand_image
    #-------------------------------------------------------------------------------------------------------
    #-- single mode
    #-- Постить один указанный файл
    mode     => 'single',
    path     => "$ENV{HOME}/chaos.png", #-- путь до изображения
    #-------------------------------------------------------------------------------------------------------
    #-- dir mode
    #-- Постить файлы из каталогов
    #mode     => 'dir',
    #order    => 'random',               #-- random - перемешать файлы
                                        ##   normal - брать по-порядку
    #path     => ["$ENV{HOME}/rm/shinku"],    #-- пути к файлу
    #types    => ['jpg', 'jpeg', 'gif', 'png'],    #-- резрешенные к загрузки типы файлов
    #-------------------------------------------------------------------------------------------------------
    #-- common options
    max_size => 500,                   #-- ограничение на размер файла в кб. Указывать ВСЕГДА.
    altering => $img_altering           #-- обход запрета на повтор картинок
};
 
#------------------------------------------------------------------------------------------------------------
# CAPTCHA SETTINGS
#------------------------------------------------------------------------------------------------------------
#-- Распознавание капчи
our $captcha_decode = {
    #-------------------------------------------------------------------------------------------------------
    #-- antigate mode
    #mode   => 'antigate',
    #key    => 'bdc525daac2c1c1a9b55a8cfaaf79792',
    #opt    => {},
    #-------------------------------------------------------------------------------------------------------
    #-- captchabot mode
    #mode   => 'captchabot',
    #key    => '202ed5073f6cd7fad6ef5d2431a96ec2',
    #opt    => {},
    #-------------------------------------------------------------------------------------------------------
    #-- hand mode
    #-- Ручной ввод капчи.
    mode   => 'hand',
    imgv   => '/usr/bin/feh',     #-- путь до программы просмотра изображений
    arg    => '-d --geometry 400x300 -Z', #-- аргументы
};     

