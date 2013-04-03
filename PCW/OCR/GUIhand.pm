package PCW::OCR::GUIhand;

use v5.12;
use utf8;
use Moo;
use Gtk2 -init;
use Coro;

sub _cap
{
    my $img_path = shift;
    my $text;

    my $w = Gtk2::Window->new("toplevel");
    $w->set_title("Введите капчу");
    $w->signal_connect( destroy => sub { Gtk2->main_quit; } );

    my $vbox  = Gtk2::VBox->new();
    $w->add($vbox);

    my $image = Gtk2::Image->new_from_file($img_path);
    $vbox->pack_start($image, 0, 0, 10);

    my $entry = Gtk2::Entry->new();
    $entry->signal_connect(
        activate => sub {
            $text = $entry->get_text;
            $w->destroy;
            Gtk2->main_quit;
        },
    );
    $vbox->pack_start($entry, 0, 0, 0);

    $w->show_all;
    Gtk2->main;
    return $text;
}

sub solve
{
    my ($self, $ocr, $file_path) = @_;
    my $text;
    eval { $text = _cap($file_path) };
    if ($@)
    {
        $ocr->log->msg('OCR_ERROR', $@, 'DECODE CAPTCHA', 'red') if $@;
        return undef;
    }
    return $text;
}

sub report_bad { }
 
1;
