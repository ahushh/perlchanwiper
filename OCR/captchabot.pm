use v5.12;
use utf8;
use File::Spec;
use FindBin qw/$Bin/;
#-- К счастью, капчабот поддерживает API антигейта

require File::Spec->catfile($Bin, 'OCR', 'antigate.pm');
$WebService::Antigate::DOMAIN = 'captchabot.com';
