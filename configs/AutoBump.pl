#------------------------------------------------------------------------------------------------------------
# CONFIG STARTS HERE
#------------------------------------------------------------------------------------------------------------
use constant BOARD    => 'b';
use constant THREAD   => 10120554;
use constant PASSWORD => 'fNfR3';

use constant BUMP_TIMEOUT => 60;
use constant INTERVAL     => 60*1;      #--Проверять, нужен ли бамп, через заданный интервал

use constant SILENT_BUMP   => 1;       #-- Удалять бампы. 0 для отключения
use constant REGEXP        => 'test';  #-- Регэксп, по которому искать посты. e.g '.*' — все посты, 'bump' — содержащие слово bump
use constant DELETE_TIMOUT => 60;

#-- Условие для бампа
use constant BUMP_IF => {
    #on_pages      => [0]  #-- бампать тред, когда он находится на заданных страницах
    not_on_pages  => [0],  #-- бампать тред, когда он НЕ находится на заданных страницах
};

#------------------------------------------------------------------------------------------------------------
# CONFIG ENDS HERE
#------------------------------------------------------------------------------------------------------------
my $find = {
    board   => BOARD,
    regexp  => REGEXP,
    threads => [THREAD],
};
my %del_set = (
    board          => BOARD,
    password       => PASSWORD,
    find           => $find,
    max_del_thrs   => 1,       #-- максимально количество запущенных потоков удаления
    delete_timeout => DELETE_TIMOUT,
);

our %mode_config = (
    bump_if   => BUMP_IF,
    timeout   => BUMP_TIMEOUT,
    interval  => INTERVAL,
    silent    => \%del_set,
    post_cnf  => {
                  #-- при указании ссылки на список, оттуда будет взято случайное значение
                  #-- например: thread     => [1,3,4,5] #-- ответ в случайный тред из заданных
                  #-- постинг на борду и в другие треды (например, [0, 435435]) лучше не смешивать.
                  board      => BOARD,
                  thread     => THREAD,
                  email      => "",
                  name       => "",
                  subject    => "",
                  password   => PASSWORD,
                 },
);
 
delete $mode_config{silent}
    unless SILENT_BUMP;
