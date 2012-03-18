our $chan_config =
{
    name               => 'Dva-ch',
    engine             => 'Wakaba',
    captcha_extension  => 'gif',
     
    response => {
        post => {
            banned        => [403, 'CDN', 'Доступ к отправке сообщений с этого ip закрыт'],
            net_error     => ['Service Unavailable Connection', 502],
            post_error    => [
                              'Этот файл уже был загружен',
                              'Либо изображение слишком большое, либо его вообще не было. Ага.',
                             ],
            wrong_captcha => [
                              'Не введен код подтверждения',
                              'Неверный код подтверждения',
                             ],
            flood         => [
                              'Ошибка: Флудить нельзя. Ваше первое сообщение уже принято', 
                              'Обнаружен флуд, файл отклонен',
                             ],
            critical_error => [
                              'Треда не существует',
                              'В этом разделе для начала треда нужно загрузить файл',
                              'Вы ничего не написали в сообщении', 
                              ],
            success       => ['Go West', 'wakaba.html'],
        },
        delete => {
            success => [303],
            error   => ['Неверный пароль для удаления', 503, 504],
        },
    },

    fields => {
        post => {
            'captcha'    => 'captcha',
            'msg'        => 'field4',
            'img'        => 'file',
            'thread'     => 'parent',
            'email'      => 'field2',
            'subject'    => 'field3',
            'password'   => 'password',
            'name'       => 'name',
            'link'       => 'link',
            'gb2'        => 'gb2',
            'task'       => 'task',
            'nofile'     => 'nofile',
        },

        delete => {
            delete   => 'delete',
            password => 'password',
            task     => 'task',
        },
    },
     
    urls => {
        post     => "http://dva-ch.ru/%s/wakaba.pl",
        delete   => "http://dva-ch.ru/%s/wakaba.pl",
        captcha  => "http://dva-ch.ru/%s/captcha.pl?key=%s&dummy=%s?",
        page     => "http://dva-ch.ru/%s/%d.html",
        zero_page    => "http://dva-ch.ru/%s",
        thread   => "http://dva-ch.ru/%s/res/%d.html",
    },

    html => {
        replies_regexp => '(?<post><td class="reply" id="reply(?<id>\d+)">.+?</td>)',
        threads_regexp => '(?<thread><span class="filesize">.+?<a name="(?<id>\d+)"></a>.+?<br clear="left" /><hr />)',
    },

    headers => {
        post => {
            'Host'               =>   'dva-ch.ru',
            'Accept'             =>   'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'Accept-Charset'     =>   'windows-1251,utf-8;q=0.7,*;q=0,7',
            'Accept-Encoding'    =>   'gzip, deflate',
            'Accept-Language'    =>   'ru-ru,ru;q=0.8,en-us;q=0.5,en;q=0.3',
            'Connection'         =>   'keep-alive',
        },
        captcha => {
            'Host'               =>   'dva-ch.ru',
            'Accept'             =>   'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'Accept-Charset'     =>   'windows-1251,utf-8;q=0.7,*;q=0,7',
            'Accept-Encoding'    =>   'gzip, deflate',
            'Accept-Language'    =>   'ru-ru,ru;q=0.8,en-us;q=0.5,en;q=0.3',
            'Connection'         =>   'keep-alive',
        },

        default => {
            'Host'               =>   'dva-ch.ru',
            'Referer'            =>   "http://dva-ch.ru/",
            'Connection'         =>   'keep-alive',
        },
    },

};
