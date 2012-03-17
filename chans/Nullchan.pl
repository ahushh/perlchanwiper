our $chan_config =
{
    name               => '0chan.ru',
    engine             => 'EFGKusaba',
    captcha_extension  => 'png',
    cookies            => ['PHPSESSID'],
    threads_per_page   => 20,

    response => {
        post => {
            banned        => [403, 'CDN', 'possible proxy'],
            net_error     => ['Service Unavailable Connection', 502],
            wrong_captcha => [
                              'капча',
                             ],
            flood         => [
                              'Вы постите очень часто.',
                              'Flood detected',
                             ],
            critical_error => [
                              ],
            file_exist    => [
                             ],
            bad_file      => [
                             ],
            success       => [302, 'BuildThread()', 'Updating pages', 504],
        },
        delete => {
            success => ['Сообщение удалено.'],
            error   => ['Неправильный пароль.', 503, 504],
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
            delete   => 'delete',
            deletepost => 'deletepost',
            password => 'postpassword',
        },
    },

    urls => {
        post      => "https://www.0chan.ru/board.php",
        delete    => "https://www.0chan.ru/board.php",
        captcha   => "https://www.0chan.ru/captcha.php",
        page      => "http://www.0chan.ru/%s/%d.html",
        zero_page => "http://www.0chan.ru/%s",
        thread    => "http://www.0chan.ru/%s/res/%d.html",
        catalog   => "http://www.0chan.ru/%s/catalog.html",
    },

    html => {
        replies_regexp => '(?<post><td class="reply" id="reply(?<id>\d+)">.+?</td>)',
        threads_regexp => '(?<thread><div id="thread(?<id>\d+)\w+">.+?</div>\s*<br clear="left">)',
        catalog_regexp => '/res/(?<id>\d+).html',
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
