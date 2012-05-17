use v5.12;
use utf8;
use File::Spec;
#-- К счастью, капчабот поддерживает API антигейта

require File::Spec->catfile('OCR', 'antigate.pm');
$WebService::Antigate::DOMAIN = 'captchabot.com';
