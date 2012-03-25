#-- Сюда вписать доменное имя
use constant HOST => 'chan-example.com';

our $chan_config =
{
    #-- Имя имиджюорды. Необязатльено для заполнения
    name               => '',
    engine             => 'Kusaba',
    captcha_extension  => 'gif',
    #-- Закомментировать, если отключена капча
    cookies            => ['PHPSESSID'],
    #-- Колличество тредов на страницу.
    #-- Нужно только автобампа и только если включен каталог
    threads_per_page   => 20,
    #-- Ключ рекапчи
    recaptcha_key      => '',

    response => {
        post => {
            banned        => [403, 'CDN'],
            net_error     => ['Service Unavailable Connection', 502],
            post_error    => [
                             ],
            wrong_captcha => [
                             ],
            flood         => [
                             ],
            critical_error => [
                              ],
            success       => [302],
        },
        delete => {
            success         => [303],
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
            MAX_FILE_SIZE => 'MAX_FILE_SIZE',
        },

        delete => {
            board      => 'board',
            delete     => 'post[]',
            deletepost => 'deletepost',
            password   => 'postpassword',
        },
    },

    urls => {
        post      => 'http://'. HOST .'/board.php',
        delete    => 'http://'. HOST .'/board.php',
        #-- Закомментировать, если капча отключена вообще или стоит recaptcha
        #captcha  => 'http://'. HOST .'/captcha.php',
        page      => 'http://'. HOST .'/%s/%d.html',
        zero_page => 'http://'. HOST .'/%s',
        thread    => 'http://'. HOST .'/%s/res/%d.html',
        #-- Закомментировать, если каталог отключен
        catalog   => 'http://'. HOST .'/%s/catalog.html',
    },

    html => {
        replies_regexp => '(?<post><td class="reply" id="reply(?<id>\d+)">.+?</td>)',
        threads_regexp => '(?<thread><span class="filesize">.+?<a name="(?<id>\d+)"></a>.+?<br clear="left" /><hr />)',
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