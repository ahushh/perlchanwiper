package PCW::Data::Video;

use v5.12;
use utf8;
use Carp;
use autodie;

use Exporter 'import';
our @EXPORT_OK = qw/make_vid/;

#------------------------------------------------------------------------------------------------
use Data::Random     qw/rand_set/;
use List::MoreUtils  qw/uniq/;
use LWP::Simple      qw/get/;
use PCW::Core::Utils qw/readfile/;

use Coro;
my $lock = Coro::Semaphore->new;

#------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------
#-- Regexp to parse ID's
my %types = ( youtube => [  'watch\?v=(?<id>(\w|-)+)&?'
                          , 'data-video-ids="(?<id>(\w|-)+)"'
                         ],
            );

my %search_urls = ( youtube => 'http://www.youtube.com/results?search_query={search}&page={page}' );

sub make_vid($$$)
{
    my ($engine, $task, $conf) = @_;
    my $vid_mode = $conf->{mode} . '_vid';
    Carp::croak sprintf "Video mode '%s' doesn't exist!\n", $conf->{mode}
            unless exists &{ $vid_mode };
    my $get_vid = \&{ $vid_mode };
    return &$get_vid($engine, $task, $conf);
}

#------------------------------------------------------------------------------------------------
# Internal functions
#------------------------------------------------------------------------------------------------
sub file_vid($$$)
{
    my (undef, undef, $data) = @_;

    state @vid_list;

    $lock->down;
    if (!@vid_list or !$data->{loaded})
    {
        @vid_list = split /\s+/, readfile($data->{path});
        $data->{loaded} = 1;
    }
    $lock->up;

    state $i = 0;

    my $video;
    if ($data->{order} eq 'random')
    {
        $video = ${ rand_set(set => \@vid_list) };
    }
    elsif ($data->{order} eq 'normal')
    {
        $i = 0 if ($i >= scalar @vid_list);
        $video = $vid_list[$i++];
    }

    return $video;
}

sub download_vid($$$)
{
    my ($engine, undef, $data) = @_;
    state @vid_list;

    $lock->down;
    if (!@vid_list or !$data->{loaded})
    {
        my $log = $engine->{log};
        $log->msg('DATA_DOWNLOAD', "Start fetching video ID's from $data->{type}..");
        my $raw;
        for my $query (@{ $data->{search}})
        {
            for my $page (1..$data->{pages})
            {
                my $url = $search_urls{ $data->{type} };
                $url =~ s/\{search\}/$query/e;
                $url =~ s/\{page\}/$page/e;
                $raw .= get($url);
                $log->msg('DATA_FOUND', "ID's were fetched from $page page and with '$query' query.");
            }
        }
        for my $pattern (@{ $types{ $data->{type} } })
        {
            while ($raw =~ /$pattern/mg)
            {
                push @vid_list, $+{id};
            }
        }
        @vid_list = uniq @vid_list;
        $log->msg('DATA_DOWNLOADED', "Fetched ". scalar(@vid_list) ." video ID's");
        if (my $path = $data->{save})
        {
            open(my $fh, '>', $path);
            print $fh "@vid_list";
            close $fh;
            $log->msg('VIDEO_SAVED', "Video ID's saved to $path");
        }
        $data->{loaded} = 1;
    }
    $lock->up;

    state $i = 0;

    my $video;
    if ($data->{order} eq 'random')
    {
        $video = ${ rand_set(set => \@vid_list) };
    }
    elsif ($data->{order} eq 'normal')
    {
        $i = 0 if ($i >= scalar @vid_list);
        $video = $vid_list[$i++];
    }
    else
    {
        Carp::croak("Order is not specified. Check your general config.");
    }
    return $video;
}

1;
