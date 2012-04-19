use constant HOST => 'www.0chan.ru';

our $chan_config =
{
    description        => 'Нульчик-стульчик',
    engine             => 'EFGKusaba',
    captcha_extension  => 'png',
    cookies            => ['PHPSESSID'],
    threads_per_page   => 20,

    response => {
        post => {
            banned        => [403, 'CDN', 'possible proxy'],
            net_error     => ['Service Unavailable Connection', 502],
            post_error    => [
                              'your message is too long',
                              'temporarily unavailable',
                              'Это видео уже опубликовано',
                              'Unable to connect to',
                             ],
            wrong_captcha => [
                              'Неправильно введена капча',
                             ],
            flood         => [
                              'Вы постите очень часто.',
                              'Flood detected',
                             ],
            critical_error => [
                               'Неправильный ID треда',
                              ],
            success       => [302, 'BuildThread()', 'Updating pages'],
        },
        delete => {
            success        => ['Сообщение удалено.'],
            wrong_password => ['Неправильный пароль.'],
            error          => [''],
        },
    },

    fields => {
        post => {
            captcha    => 'captcha',
            board      => 'board',
            msg        => 'message',
            img        => 'imagefile',
            thread     => 'replythread',
            email      => 'em',
            subject    => 'subject',
            password   => 'postpassword',
            name       => 'name',
            nofile     => 'nofile',
            mm         => 'mm',
            video      => 'embed',
            video_type => 'embedtype',
            MAX_FILE_SIZE => 'MAX_FILE_SIZE',
        },

        delete => {
            board      => 'board',
            delete     => 'delete',
            deletepost => 'deletepost',
            password   => 'postpassword',
        },
    },

    urls => {
        post      => 'https://'. HOST .'/board.php',
        delete    => 'https://'. HOST .'/board.php',
        captcha   => 'https://'. HOST .'/captcha.php',
        page      => 'http://'. HOST .'/%s/%d.html',
        zero_page => 'http://'. HOST .'/%s',
        thread    => 'http://'. HOST .'/%s/res/%d.html',
        catalog   => 'http://'. HOST .'/%s/catalog.html',
    },

    html => {
        replies_regexp => '(?<post><td class="reply" id="reply(?<id>\d+)">.+?</td>)',
        threads_regexp => '(?<thread><div id="thread(?<id>\d+)\w+">.+?</div>\s*<br clear="left">)',
        catalog_regexp => '/res/(?<id>\d+).html',
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
            'Accept'             =>   'image/png,image/*;q=0.8,*/*;q=0.5',
            'Accept-Charset'     =>   'windows-1251,utf-8;q=0.7,*;q=0,7',
            'Accept-Encoding'    =>   'gzip, deflate',
            'Accept-Language'    =>   'ru-ru,ru;q=0.8,en-us;q=0.5,en;q=0.3',
            'Connection'         =>   'keep-alive',
        },

        default => {
            'Host'               =>   HOST,
            'Referer'            =>   'https://'. HOST .'/',
            'Connection'         =>   'keep-alive',
        },
    },

};
