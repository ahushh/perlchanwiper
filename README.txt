Контакты
~~~~~~~~
ahushh@gmail.com

Описание
--------
Консольная вайпалка/бампалка для имиджборд на движках Kusaba и Wakaba

Режимы работы
~~~~~~~~~~~~~
* Wipe         — вайп доски/тредов/рандомных тредов
* AutoBump     — автобампалка, следящая за положение треда на доске и удаляющая за собой посты
* ProxyChecker — прокси чекер специально для чанов
* Delete       — удалялка постов

Файлы и каталоги
~~~~~~~~~~~~~~~~
* cpcw         — запуск
* proxychecker — простой прокси чекер, работающий на основе WWW:ProxyChecker
* config.pl    — общие настройки
* configs      — настройки для модов (Wipe, AutoBump, Delete, ProxyChecker)
* OCR          — скрипты, распознающие капчу
* captcha      — сохраненные файлы капчи (см. опцию 'save_captcha' режима wipe)
* chans        — настройки для чанов
* lib          — сторонние модифицированные библиотеки и бинарники

Примеры использования
---------------------
Вайп:
./cpcw --mode Wipe --chan Nullchan --proxy proxy/my/0chan

Автобамп:
./cpcw --mode AutoBump --chan Nullchan --loglevel 2

Примечания
----------
* На нульчане в /b/ не работает постинг не ascii-символов — ошибка 'flood detect'
* Для отключения каталога (например для автобампа 2.0 досок на нульчане)
  в файле конфигурации чана в секции 'urls' закоммnентировать строку
  catalog => ...

Установка
---------
См. файл INSTALL

Добавление новых чанов
----------------------
См. файлы 'chans/wakaba.example.pl' и 'chans/kusaba.example.pl'

Прочее
------
* При проблемах с цветным выводом логов нужно отредактировать файл * 'PCW/Core/Log.pm'

FAQ
---
Как установить диапазон символов, которые будет распознавать tesseract?
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

1.  Создать конфиг (например 'englishletters') в tessdate/configs - обычно
    /usr/share/tesseract/tessdata/configs
    или
    /usr/share/tesseract-ocr/tessdata/configs

2.  Отредактировать его например так (для английских строчных буквы):
    tessedit_char_whitelist abcdefghijklmnopqrstuvwxyz

    На месте 'abcdefghijklmnopqrstuvwxyz указываются допустимые для
    распознавания символы.

    Или так (распознаваться будут только цифры):
    tessedit_char_whitelist 0123456789

3.  Отредактировать общий конфиг (./config.pl):
    config => 'englishletters',

Не работают socks-прокси!
+++++++++++++++++++++++++

1.  В файле 'PCW/Core/Net.pm' раскомментировать строку
    #use LWP::Protocol::socks;

2.  Установить модуль 'LWP::Protocol::socks' через CPAN:
    sudo cpan LWP::Protocol::socks
    Если повезет, оно соберется и заработает. Но я бы не надеялся.

    Или через пакеты дистрибутива. Например, для apt-based:
    apt-get install liblwp-protocol-socks-perl
