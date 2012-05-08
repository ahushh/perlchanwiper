#-- Сюда вписать доменное имя
use constant HOST => 'www.0-chan.ru';

our $chan_config =
{
    #-- Описание. Необязатльено для заполнения
    description        => 'Лженульчан',
    engine             => 'Kusaba',
    captcha_extension  => 'png',
    #-- Закомментировать, если отключена капча
    cookies            => ['PHPSESSID'],
    #-- Колличество тредов на страницу.
    #-- Нужно только автобампа и только если включен каталог
    threads_per_page   => 20,
    #-- Ключ рекапчи
    #recaptcha_key      => '6LdVg8YSAAAAAOhqx0eFT1Pi49fOavnYgy7e-lTO',

    response => {
        post => {
            banned        => [403, 'CDN', 'banned', 'забанены', 'BANNED!'],
            net_error     => ['Service Unavailable Connection', 502, 500, 504, 503],
            post_error    => [
                              'your message is too long',
                              'temporarily unavailable',
                              'Это видео уже опубликовано',
                              'Уже опубликовано тут', 
                              'Unable to connect to',
                             ],
            wrong_captcha => [
                              'неправильный код подтверждения',
                             ],
            flood         => [
                              'Вы постите очень часто.',
                              'Flood detected',
                              'Please wait a moment before posting again',
                             ],
            critical_error => [
                               'Неправильный ID треда',
                              ],
            success       => ['BuildThread()', 'Updating pages', 302],

        },
        delete => {
            success        => [303],
            wrong_password => ['Неправильный пароль.'],
            error          => [''],
        },
    },

    fields => {
        post => {
            captcha    => 'captcha',
            #captcha    => 'recaptcha_response_field',
            board      => 'board',
            msg        => 'message',
            img        => 'imagefile',
            thread     => 'replythread',
            email      => 'em',
            subject    => 'subject',
            password   => 'postpassword',
            name       => 'name',
            nofile     => 'nofile',
            video      => 'embed',
            video_type => 'embedtype',
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
        captcha  => 'http://'. HOST .'/captcha/image.php',
        page      => 'http://'. HOST .'/%s/%d.html',
        zero_page => 'http://'. HOST .'/%s',
        thread    => 'http://'. HOST .'/%s/res/%d.html',
        #-- Закомментировать, если каталог отключен
        catalog   => 'http://'. HOST .'/%s/catalog.html',
    },

    html => {
        replies_regexp => '(?<post><td class="reply" id="reply(?<id>\d+)">.+?</td>)',
        #threads_regexp => '(?<thread><span class="filesize">.+?<a name="(?<id>\d+)"></a>.+?<br clear="left" /><hr />)',
        threads_regexp => '(?<thread><div id="thread(?<id>\d+)\w+">.+?</div>\s*</blockquote>\s*</div>)',
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
