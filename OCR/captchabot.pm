use strict;
use File::Spec;
#-- К счастью, капчабот поддерживает API антигейта

require File::Spec->catfile('OCR', 'antigate.pm');
$WebService::Antigate::DOMAIN = 'captchabot.com';
