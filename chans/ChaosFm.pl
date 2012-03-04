our $chan_config =
{
    name               => 'Chaos.fm',
    engine             => 'Wakaba',
    captcha_extension  => 'gif',
     
    response => {
        post => {
            banned        => [403, 'CDN', 'Доступ к отправке сообщений с этого ip закрыт'],
            net_error     => ['Service Unavailable Connection', 502],
            wrong_captcha => [
                              'Не введен код подтверждения',
                              'Неверный код подтверждения',
                             ],
            flood         => [
                              'Error: Flood detected, post discarded.' 
                             ],
            critical_error => [
                              'Треда не существует',
                              'В этом разделе для начала треда нужно загрузить файл',
                              'Вы ничего не написали в сообщении', 
                              ],
            file_exist    => [
                              'Этот файл уже был загружен',
                             ],
            bad_file      => [
                              'Либо изображение слишком большое, либо его вообще не было. Ага.',
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
        post     => "http://chaos.fm/%s/wakaba.pl",
        delete   => "http://chaos.fm/%s/wakaba.pl",
        captcha  => "http://chaos.fm/%s/captcha.pl?key=%s&dummy=%s?",
        page     => "http://chaos.fm/%s/%d.html",
        zero_page    => "http://chaos.fm/%s",
        thread   => "http://chaos.fm/%s/res/%d.html",
    },

    html => {
        replies_regexp => '(?<post><td class="reply" id="reply(?<id>\d+)">.+?</td>)',
        threads_regexp => '(?<thread><span class="filesize">.+?<a name="(?<id>\d+)"></a>.+?<br clear="left" /><hr />)',
    },

    headers => {
        post => {
            'Host'               =>   'chaos.fm',
            'Accept'             =>   'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'Accept-Charset'     =>   'windows-1251,utf-8;q=0.7,*;q=0,7',
            'Accept-Encoding'    =>   'gzip, deflate',
            'Accept-Language'    =>   'ru-ru,ru;q=0.8,en-us;q=0.5,en;q=0.3',
            'Connection'         =>   'keep-alive',
        },

        default => {
            'Host'               =>   'chaos.fm',
            'Referer'            =>   "http://chaos.fm/",
            'Connection'         =>   'keep-alive',
        },
    },

};
