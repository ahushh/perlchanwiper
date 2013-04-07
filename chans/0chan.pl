 use utf8;
 use constant HOST  => '0chan.hk';

 our $chan_config =
 {
  description        => 'Нульчик-стульчик',
  engine             => 'EFGKusaba',
  captcha_extension  => 'png',
  captcha_cookies    => ['PHPSESSID', 'cap'],
  threads_per_page   => 20,
  new_thread_delay   => 30*60,
  reply_delay        => 10,
  captcha_enabled    => 1,

  response => {
               post => {
                        banned        => [403, 'CDN', 'possible proxy', 'BANNED', 'Blacklisted text detected.'],
                        net_error     => ['Service Unavailable Connection', 502, 500],
                        post_error    => [
                                          'your message is too long',
                                          'temporarily unavailable',
                                          'Это видео уже опубликовано',
                                          'Уже опубликовано тут',
                                          'Unable to connect to',
                                         ],
                        wrong_captcha => [
                                          'Неправильно введена капча',
                                          'captcha timed out',
                                         ],
                        same_message   => [
                                           'Flood detected',
                                          ],
                        too_fast       => [
                                           'You are currently posting faster',
                                          ],
                        critical_error => [
                                           'Неправильный ID треда',
                                           'Требуется приложить файл для создания треда',
                                          ],
                        success       => ['BuildThread()', 'Updating pages', 'Website is currently unavailable'],
                       },
               delete => {
                          success        => ['Сообщение удалено.'],
                          wrong_password => ['Неправильный пароль.'],
                          error          => ['Invalid post ID'],
                         },
              },

  fields => {
             post => {
                      _captcha    => 'captcha',
                      _board      => 'board',
                      _message    => 'message',
                      _image      => 'imagefile',
                      _thread     => 'replythread',
                      _email      => 'em',
                      _subject    => 'subject',
                      _password   => 'postpassword',
                      _name       => 'name',
                      _video      => 'embed',
                      _video_type => 'embedtype',
                      nofile      => 'nofile',
                      mm          => 'mm',
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
           post      => 'http://'. HOST .'/board.php',
           delete    => 'http://'. HOST .'/board.php',
           captcha   => 'http://'. HOST .'/captcha.php',
           page      => 'http://'. HOST .'/%s/%d.html',
           zero_page => 'http://'. HOST .'/%s',
           thread    => 'http://'. HOST .'/%s/res/%d.html',
           catalog   => 'http://'. HOST .'/%s/catalog.html',
          },

  html => {
           replies => undef,
           threads => undef,
           catalog => undef,
           message => undef,
           img_url => undef,
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
