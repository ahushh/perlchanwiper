#Контакты
ahushh@gmail.com
#Описание
Консольная вайпалка/бампалка для имиджборд на движках Kusaba и Wakaba
##Режимы работы
* wipe — вайп доски/тредов/рандомных тредов
* autobump — автобампалка, следящая за положение треда на доске
* proxychecker — прокси чекер специально для чанов. но сыроват
* delete — удалялка постов
#Примеры использования
         ./PCW.pl --mode wipe --chan Nullchan --proxy proxy/my/0chan
         ./PCW.pl --mode delete --chan Nullchan --loglevel 2 --verbose
#Установка
См. файл INSTALL
#Добавление новых чанов
См. файлы chans/wakaba.example.pl и chans/kusaba.example.pl
#Описание файлов и каталогов
* PCW.pl       — главный скрипт
* proxychecker — простой прокси чекер, работающий на основе WWW:ProxyChecker
* config.pl    — общие настройки
* configs      — настройки для модов
* OCR          — скрипты, распознающие капчу
* captcha      — сохраненные файлы капчи (см. опцию 'save_captcha' режима wipe)
* chans        — настройки для чанов
* lib          — сторонние библиотеки и бинарники
#Прочее
* При проблемах с цветным выводом логов нужно отредактировать файл PCW/Core/Log.pm
