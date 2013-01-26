use utf8;
#-- Сюда вписать доменное имя
use constant HOST => '2ch.hk';

our $chan_config =
{
    #-- Описание. Необязатльено для заполнения
    description        => 'сосач',
    engine             => 'Sosaba',
    captcha_extension  => 'gif',
    #-- Ключ рекапчи
    recaptcha_key      => '',

    response => {
        post => {
            banned        => [403, 'Доступ к отправке сообщений с этого IP закрыт'],
            net_error     => ['Service Unavailable Connection', 502],
            post_error    => [
                              'Этот файл уже был загружен',
                              'Либо изображение слишком большое, либо его вообще не было. Ага.',
                             ],
            wrong_captcha => [
                              'Неверный код подтверждения',
                              'Вероятно, вы забыли ввести капчу для отправки сообщений',
                             ],
            flood         => [
                              'Обнаружен флуд, пост не отправлен',
                              'Вы уже создали один тред',
                             ],
            critical_error => [
                              'Треда не существует',
                              'В этом разделе для начала треда нужно загрузить файл',
                              'Вы ничего не написали в сообщении',
                              ],
            success       => [303],
        },
        delete => {
        },
    },

    fields => {
        post => {
            captcha     => 'captcha_value',
            captcha_key => 'captcha',
            msg         => 'shampoo',
            img         => 'file',
            thread      => 'parent',
            email       => 'nabiki',
            subject     => 'kasumi',
            name        => 'name',
            akane       => 'akane',
            task        => 'task',
            submit      => 'submit',
            video       => 'video',
            link        => 'link',
            makewatermark => 'makewatermark',
        },

        delete => {
        },
    },

    urls => {
        post      => 'http://'. HOST .'/%s/wakaba.pl',
        delete    => 'dont give a fuck',
        captcha   => 'http://'. HOST .'/makaba/captcha.fcgi',
        page      => 'http://'. HOST .'/%s/%d.html',
        zero_page => 'http://'. HOST .'/%s',
        thread    => 'http://'. HOST .'/%s/res/%d.html',
    },

    html => {
        replies_regexp => '(?<post><table id="post_(?<id>\d+)" class="post">.+?</table>(<table|</div))',
        threads_regexp => '(?<thread><div id="thread_(?<id>\d+)" class="thread">.+?</div><br style="clear:left;" />)',
        text_regexp    => '<blockquote id="m\d+" class="postMessage"><p>(?<text>.*)</p></blockquote>',
        img_regexp     => '(?<img>)',
    },

    headers => {
        post => {
            # 'Host'               =>   HOST,
            # 'Accept'             =>   'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            # 'Accept-Charset'     =>   'windows-1251,utf-8;q=0.7,*;q=0,7',
            # 'Accept-Encoding'    =>   'gzip, deflate',
            # 'Accept-Language'    =>   'ru-ru,ru;q=0.8,en-us;q=0.5,en;q=0.3',
            # 'Connection'         =>   'keep-alive',
        },
        captcha => {
            # 'Host'               =>   HOST,
            # 'Accept'             =>   'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            # 'Accept-Charset'     =>   'windows-1251,utf-8;q=0.7,*;q=0,7',
            # 'Accept-Encoding'    =>   'gzip, deflate',
            # 'Accept-Language'    =>   'ru-ru,ru;q=0.8,en-us;q=0.5,en;q=0.3',
            # 'Connection'         =>   'keep-alive',
        },

        default => {
            'Host'               =>   HOST,
            'Referer'            =>   'http://'. HOST .'/',
            'Connection'         =>   'keep-alive',
        },
    },

};
