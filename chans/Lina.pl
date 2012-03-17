our $chan_config =
{
    name               => 'lina.sytes.net',
    engine             => 'Kusaba',
    captcha_extension  => 'gif',
    cookies            => ['PHPSESSID'],
    threads_per_page   => 20,
     
    response => {
        post => {
            banned        => [403, 'CDN'],
            net_error     => ['Service Unavailable Connection', 502],
            wrong_captcha => [
                             ],
            flood         => [
                             ],
            critical_error => [
                              ],
            file_exist    => [
                             ],
            bad_file      => [
                             ],
            success       => [302],
        },
        delete => {
            success => [303],
            error   => ['Неверный пароль для удаления', 503, 504],
        },
    },

    fields => {
        post => {
            'captcha'    => 'captcha',
            'board'      => 'board',
            'msg'        => 'message',
            'img'        => 'imagefile',
            'thread'     => 'replythread',
            'email'      => 'em',
            'subject'    => 'subject',
            'password'   => 'postpassword',
            'name'       => 'name',
            'nofile'     => 'nofile',
             MAX_FILE_SIZE => 'MAX_FILE_SIZE',
        },

        delete => {
            board    => 'board',
            delete   => 'post[]',
            deletepost => 'deletepost',
            password => 'postpassword',
        },
    },
     
    urls => {
        post      => "http://lina.sytes.net/board.php",
        delete    => "http://lina.sytes.net/board.php",
        #captcha  => "http://lina.sytes.net/captcha.php",
        captcha   => "",
        page      => "http://lina.sytes.net/%s/%d.html",
        zero_page => "http://lina.sytes.net/%s",
        thread    => "http://lina.sytes.net/%s/res/%d.html",
        catalog   => "http://lina.sytes.net/%s/catalog.html",
    },

    html => {
        replies_regexp => '(?<post><td class="reply" id="reply(?<id>\d+)">.+?</td>)',
        threads_regexp => '(?<thread><span class="filesize">.+?<a name="(?<id>\d+)"></a>.+?<br clear="left" /><hr />)',
    },

    headers => {
        post => {
            'Host'               =>   'lina.sytes.net.ru',
            'Accept'             =>   'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'Accept-Charset'     =>   'windows-1251,utf-8;q=0.7,*;q=0,7',
            'Accept-Encoding'    =>   'gzip, deflate',
            'Accept-Language'    =>   'ru-ru,ru;q=0.8,en-us;q=0.5,en;q=0.3',
            'Connection'         =>   'keep-alive',
        },
        captcha => {
            'Host'               =>   'lina.sytes.net.ru',
            'Accept'             =>   'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'Accept-Charset'     =>   'windows-1251,utf-8;q=0.7,*;q=0,7',
            'Accept-Encoding'    =>   'gzip, deflate',
            'Accept-Language'    =>   'ru-ru,ru;q=0.8,en-us;q=0.5,en;q=0.3',
            'Connection'         =>   'keep-alive',
        },

        default => {
            'Host'               =>   'lina.sytes.net.ru',
            'Referer'            =>   "http://lina.sytes.net/",
            'Connection'         =>   'keep-alive',
        },
    },

};
