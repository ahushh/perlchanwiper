use utf8;
#------------------------------------------------------------------------------------------------------------
# CONFIG STARTS HERE
#------------------------------------------------------------------------------------------------------------
use constant BOARD    => 'b';
use constant THREAD   => 10499356;
use constant PASSWORD => 'fNfR3';

use constant BUMP_TIMEOUT => 160;
use constant INTERVAL     => 60*1;      #--Проверять, нужен ли бамп, через заданный интервал

use constant SILENT_BUMP   => 1;       #-- Удалять бампы. 0 для отключения
use constant REGEXP        => 'autobump';  #-- Регэксп, по которому искать посты. e.g '.*' — все посты, 'bump' — содержащие слово bump
use constant DELETE_TIMOUT => 60;

#-- Условие для бампа
use constant BUMP_IF => {
    # on_pages      => [0]  #-- бампать тред, когда он находится на заданных страницах
    not_on_pages  => [0],  #-- бампать тред, когда он НЕ находится на заданных страницах
};

#------------------------------------------------------------------------------------------------------------
# CONFIG ENDS HERE
#------------------------------------------------------------------------------------------------------------
my $find = {
    board   => BOARD,        #-- доска, на которой искать посты
    replies => {
        threads => [THREAD],     #-- в каких тредах искать (по id)
        regexp  => REGEXP,       #-- филтровать по регэкспу
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
#-- watchers
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
my $w_target_cnf = { #-- текущая конфигурация - ищется последний номер RMT на доске _nrmt
                    interval  => 60*10,  #-- интервал обновления списка постов
                    #-- найденные номера постов будут присвоены $post_cnf{thread}
                    board     => 'b',   #-- доска, на которой искать треды
                    #board     => 'b',   #-- доска, на которой искать треды
                    take      => 'last', #-- all - все посты, random - случайный, last - последний

                     threads => {
                                 #post_limit => 300,  #-- TODO
                                 regexp  => 'kuudere',   #-- фильтровать по регэкспу
                                 pages   => [0..4], #-- на каких страницах искать треды, в которые нужно отвечать
                                 include => 1,
                                 #in_text => '',     #-- искать номера постов в тексте треда по регэкспу
                                 #regexp  => '<blockquote><div class="postmessage">(\s+)?</div></blockquote>',
                                 #pages   => [0], #-- на каких страницах искать треды, в которые нужно отвечать
                                 #include => 1,
                                 #in_text => '',     #-- искать номера постов в тексте треда по регэкспу
                                },
                    #replies => {
                     #   include => 1,
                        #threads => 'found', #-- искать в уже найденных тредах (см. выше)
                      #  threads => [1199], #-- искать в уже найденных тредах (см. выше)
                       # regexp  => '',    #-- филтровать по регэкспу
                        #in_text => '&gt;&gt;/b/(?<post>\d+)',     #-- искать номера постов в тексте ответа по регэкспу
                    #},

                   };

my $w_target_cb = sub
{
    use Coro;
    my ($self, $conf, $queue) = @_;
    async {
        my $coro = $Coro::current;
        $coro->desc('custom-watcher');
        my @posts = $self->get_posts_by_regexp("http://no_proxy", $conf);
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
    watchers => #-- Кастомные вотчеры. Для отключения закомментировать.
    {
        # coros  => { #-- вывод количества запущенных и находящихся в очереди тредов
        #     cb       => $w_coros_cb,
        #     after    => 0,
        #     interval => 5,
        #     conf     => { loglevel => 1 },
        #     on_start => 1,       #-- 1 - выполнять ф-ю перед стартом
        #                          #   2 - выполнить ф-ю только перед стартом и не инициализировать
        #     type     => 'timer', #-- тип вотчера, пока только AnyEvent->timer
        # },
         target => {  #-- поиск треда
             cb       => $w_target_cb,
             after    => $w_target_cnf->{interval},
             interval => $w_target_cnf->{interval},
             conf     => $w_target_cnf,
             on_start => 1,       #-- 1 - выполнять ф-ю перед стартом
                                  #   2 - выполнить ф-ю только перед стартом и не инициализировать
             type     => 'timer', #-- тип вотчера, пока только AnyEvent->timer
         },
    },
);
 
delete $mode_config{silent}
    unless SILENT_BUMP;
