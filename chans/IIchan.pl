use utf8;
use constant HOST => 'iichan.hk';

our $chan_config =
{
    #-- Описание. Необязатльено для заполнения
    description        => 'сырнач',
    engine             => 'Wakaba',
    captcha_extension  => 'gif',
    #-- Ключ рекапчи
    recaptcha_key      => '',

    response => {
        post => {
            banned        => [403, 'CDN', 'Open proxy detected.','Доступ к отправке сообщений с этого ip закрыт', 'Доступ с этого хоста запрещён.'],
            net_error     => ['Service Unavailable Connection', 502],
            post_error    => [
                              'Этот файл уже был загружен',
                              'Либо изображение слишком большое, либо его вообще не было. Ага.',
                              'Сообщения без изображений запрещены',
                              'Строка отклонена',
                             ],
            wrong_captcha => [
                              'Введён неверный код подтверждения',
                              'Код подтверждения не найден в базе',
                             ],
            flood         => [
                              'Ошибка: Флудить нельзя. Ваше первое сообщение уже принято',
                              'Обнаружен флуд, файл отклонен',
                             ],
            critical_error => [
                              'Тред не существует',
                              'В этом разделе для начала треда нужно загрузить файл',
                              'Вы ничего не написали в сообщении',
                              ],
            success       => ['Go West', 'wakaba.html', 303],
        },
        delete => {
            success        => [303],
            wrong_password => ['Неправильный пароль.', 'Неверный пароль для удаления'],
            error          => [''],

        },
    },

    fields => {
        post => {
            captcha    => 'captcha',
            msg        => 'nya4',
            img        => 'file',
            thread     => 'parent',
            email      => 'nya2',
            subject    => 'nya3',
            password   => 'password',
            name       => 'name',
            link       => 'link',
            gb2        => 'postredir',
            task       => 'task',
            nofile     => 'nofile',
        },

        delete => {
            delete   => 'delete',
            password => 'password',
            task     => 'task',
        },
    },

    urls => {
        post      => 'http://'. HOST .'/cgi-bin/wakaba.pl/%s/',
        delete    => 'http://'. HOST .'/cgi-bin/wakaba.pl/%s/',
        #-- Закомментировать, если капча отключена вообще или стоит recaptcha
        captcha   => 'http://'. HOST .'/cgi-bin/captcha1.pl/%s/?key=%s&dummy=%s?',
        page      => 'http://'. HOST .'/%s/%d.html',
        zero_page => 'http://'. HOST .'/%s',
        thread    => 'http://'. HOST .'/%s/res/%d.html',
    },

    html => {
        replies_regexp => '(?<post><td class="reply" id="reply(?<id>\d+)">.+?</td>)',
        threads_regexp => '(?<thread><span class="filesize">.+?<a name="(?<id>\d+)"></a>.+?<br clear="left" /><hr />)',
        text_regexp    => '',
        img_regexp     => '(?<img>)',
    },

    headers => {
        post => {
            'Host'               =>   HOST,
            'Accept'             =>   'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'Accept-Charset'     =>   'windows-1251,utf-8;q=0.7,*;q=0,7',
            'Accept-Encoding'    =>   'gzip, deflate',
            'Accept-Language'    =>   'ru-ru,ru;q=0.8,en-us;q=0.5,en;q=0.3',
            'Connection'         =>   'keep-alive',
        },
        captcha => {
            'Host'               =>   HOST,
            'Accept'             =>   'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'Accept-Charset'     =>   'windows-1251,utf-8;q=0.7,*;q=0,7',
            'Accept-Encoding'    =>   'gzip, deflate',
            'Accept-Language'    =>   'ru-ru,ru;q=0.8,en-us;q=0.5,en;q=0.3',
            'Connection'         =>   'keep-alive',
        },

        default => {
            'Host'               =>   HOST,
            'Referer'            =>   'http://'. HOST .'/',
            'Connection'         =>   'keep-alive',
        },
    },

};
