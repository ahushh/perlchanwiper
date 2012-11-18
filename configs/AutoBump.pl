use utf8;
#------------------------------------------------------------------------------------------------------------
# BASE CONFIG STARTS HERE
#------------------------------------------------------------------------------------------------------------
#-- доска и номер треда, который нужно бампать
#-- игнорируются, если включен вотчер target
use constant BOARD    => 'b';
use constant THREAD   => 10122508;
#-- включить вотчер target - автоматический поиск тредов на доске
#   см. настройки в $w_target_cnf ниже
#   работает кривовато
use constant TARGET   => 1;

use constant PASSWORD     => 'fNfR3';
use constant BUMP_TIMEOUT => 160;
use constant INTERVAL     => 60*1;         #--Проверять, нужен ли бамп, через заданный интервал

use constant SILENT_BUMP   => 1;           #-- Удалять бампы. 0 для отключения
use constant REGEXP        => 'autobump';  #-- Регэксп, по которому искать посты. e.g '.*' — все посты, 'bump' — содержащие слово bump
use constant DELETE_TIMOUT => 60;

#-- Условие для бампа
use constant BUMP_IF => {
    # on_pages      => [0] #-- бампать тред, когда он находится на заданных страницах
    not_on_pages  => [0],  #-- бампать тред, когда он НЕ находится на заданных страницах
    #-- TODO: пока не сделано
    # notification  => 0     #-- 1 - показывать всплывающее окно с позицией треда, если тред нужно бампануть
    #                        #-- 1 - показывать всплывающее окно с позицией треда при каждой проверки
    # notify        => 'notify-send' #-- команда для notify
};

#------------------------------------------------------------------------------------------------------------
# BASE CONFIG ENDS HERE
#------------------------------------------------------------------------------------------------------------
#-- настройки ниже кроме $w_target_cnf лучше не трогать
my $find = {
    board   => BOARD,        #-- доска, на которой искать посты
    replies => {
        threads => [THREAD],     #-- в каких тредах искать (по id)
        regexp  => REGEXP,       #-- фильтровать по регэкспу
        include => 1,
        take    => 'all',
    },
};

my %del_set = (
    board          => BOARD,
    password       => PASSWORD,
    find           => $find,
    max_del_thrs   => 1,       #-- максимально количество запущенных потоков удаления
    delete_timeout => DELETE_TIMOUT,
);

#------------------------------------------------------------------------------------------------------------
#-- WATCHERS
#------------------------------------------------------------------------------------------------------------
#-- вывод количества запущенных и находящихся в очереди тредов
my $w_coros_cb = sub
{
    use Coro;
    my ($self, $conf, $queue) = @_;
    async {
        my $coro = $Coro::current;
        $coro->desc('custom-watcher');

        my @bump_coro   = grep { $_->desc ? ($_->desc eq 'bump'  ) : 0 } Coro::State::list;
        my @delete_coro = grep { $_->desc ? ($_->desc eq 'delete') : 0 } Coro::State::list;

        $self->{log}->msg($conf->{loglevel}, sprintf "run: %d bump, %d delete.",
            scalar @bump_coro, scalar @delete_coro);
        $self->{log}->msg($conf->{loglevel}, sprintf "queue: %d bump, %d delete.",
            $queue->{bump}->size, $queue->{delete}->size);
    };
    cede;
};
#------------------------------------------------------------------------------------------------------------
#-- поиск треда
#-- !! тред и страницы качаются БЕЗ ПРОКСИ
my $w_target_cnf = { #-- текущая конфигурация - ищется последний номер RMT на доске _nrmt и выбирается в кач-ве треда для автобампа
                    board     => '_nrmt',   #-- доска, на которой искать треды
                    take      => 'last',    #-- all - все посты, random - случайный, last - последний

                     # threads => {
                     #             post_limit => 300,    #-- TODO
                     #             regexp     => '',     #-- фильтровать по регэкспу
                     #             pages      => [0..4], #-- на каких страницах искать треды, в которые нужно отвечать
                     #             include    => 1,      #-- использовать найденные треды или нет
                     #             in_text    => '',     #-- искать номера постов в тексте треда по регэкспу
                     #             regexp     => '<blockquote><div class="postmessage">(\s+)?</div></blockquote>',
                     #            },
                    replies => {
                       include => 1,
                       # threads => 'found',     #-- искать в уже найденных тредах (см. выше)
                       threads => [1],        #-- искать в уже найденных тредах (см. выше)
                       # regexp  => '',          #-- фильтровать по регэкспу
                       in_text => '&gt;&gt;/b/(?<post>\d+)',     #-- искать номера постов в тексте ответа по регэкспу
                    },
                   };

my $w_target_cb = sub
{
    use Coro;
    my ($self, $conf, $queue) = @_;
    async {
        use PCW::Core::Utils qw/get_posts_ids/;
        my $coro = $Coro::current;
        $coro->desc('custom-watcher');
        my @posts = get_posts_ids($self->{engine}, "http://no_proxy", $conf);
        $self->{conf}{post_cnf}{thread} = $posts[0];
        $self->{conf}{silent}{find}{replies}{threads} = [ $posts[0] ]; #-- треды, в которых ищутся посты на удаление
    };
    cede;
};

#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------

our %mode_config = (
    bump_if   => BUMP_IF,
    timeout   => BUMP_TIMEOUT,
    interval  => INTERVAL,
    silent    => \%del_set,
    post_cnf  => {
                  #-- при указании ссылки на список, оттуда будет взято случайное значение
                  #-- например: thread     => [1,3,4,5] #-- ответ в случайный тред из заданных
                  board      => BOARD,
                  thread     => THREAD,
                  email      => "",
                  name       => "",
                  subject    => "",
                  password   => PASSWORD,
                 },
    watchers => #-- Кастомные вотчеры
    {
        coros  => { #-- вывод количества запущенных и находящихся в очереди тредов
            cb       => $w_coros_cb,
            after    => 0,
            interval => 5,
            conf     => { loglevel => 1 },
            on_start => 1,       #-- 1 - выполнять ф-ю перед стартом
                                 #   2 - выполнить ф-ю только перед стартом и не инициализировать
                                 #   0 - выполнять функцию во время старта
            type     => 'timer', #-- тип вотчера, пока только AnyEvent->timer
            enable   => 1,       #-- 1 - включить, 0 - отключить
        },
         target => {  #-- поиск треда
             cb       => $w_target_cb,
             after    => $w_target_cnf->{interval},
             interval => $w_target_cnf->{interval},
             conf     => $w_target_cnf,
             on_start => 1,       #-- 1 - выполнять ф-ю перед стартом
                                  #   2 - выполнить ф-ю только перед стартом и не инициализировать
                                  #   0 - выполнять функцию во время старта
             type     => 'timer', #-- тип вотчера, пока только AnyEvent->timer
             enable   => TARGET,  #-- 1 - включить, 0 - отключить
         },
    },
);
 
delete $mode_config{silent}
    unless SILENT_BUMP;
