our $chan_config =
{
    name               => '0chan.ru',
    engine             => 'EFGKusaba',
    captcha_extension  => 'png',
    # cookies            => ['PHPSESSID', 'cap'],
    cookies            => ['PHPSESSID'],

    response => {
        post => {
            banned        => [403, 'CDN'],
            net_error     => ['Service Unavailable Connection', 502],
            wrong_captcha => [
                             ],
            flood         => [
                              'Flood detected',
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
            'mm'         => 'mm',
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
        post     => "https://0chan.ru/board.php",
        delete   => "https://0chan.ru/board.php",
        captcha  => "https://0chan.ru/captcha.php",
        page     => "https://0chan.ru/%s/%d.html",
        zero_page    => "https://0chan.ru/%s",
        thread   => "https://0chan.ru/%s/res/%d.html",
    },

    html => {
        replies_regexp => '(?<post><td class="reply" id="reply(?<id>\d+)">.+?</td>)',
        threads_regexp => '(?<thread><span class="filesize">.+?<a name="(?<id>\d+)"></a>.+?<br clear="left" /><hr />)',
    },

    headers => {
        post => {
            'Host'               =>   'www.0chan.ru',
            'Accept'             =>   'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'Accept-Charset'     =>   'windows-1251,utf-8;q=0.7,*;q=0,7',
            'Accept-Encoding'    =>   'gzip, deflate',
            'Accept-Language'    =>   'ru-ru,ru;q=0.8,en-us;q=0.5,en;q=0.3',
            'Connection'         =>   'keep-alive',
        },
        captcha => {
            'Host'               =>   'www.0chan.ru',
            'Accept'             =>   'image/png,image/*;q=0.8,*/*;q=0.5',
            'Accept-Charset'     =>   'windows-1251,utf-8;q=0.7,*;q=0,7',
            'Accept-Encoding'    =>   'gzip, deflate',
            'Accept-Language'    =>   'ru-ru,ru;q=0.8,en-us;q=0.5,en;q=0.3',
            'Connection'         =>   'keep-alive',
        },

        default => {
            'Host'               =>   'www.0chan.ru',
            'Referer'            =>   "https://0chan.ru/",
            'Connection'         =>   'keep-alive',
        },
    },

};
