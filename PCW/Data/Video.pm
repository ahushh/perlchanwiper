package PCW::Data::Video;

use v5.12;
use utf8;
use Carp qw/croak/;
use Moo;
use autodie;

has 'video_list' => (
    is => 'rw',
);

has 'loaded' => (
    is      => 'rw',
    default => sub { 0 },
);

has 'hosters' => (
    is => 'ro',
    default => sub {
        [ youtube => {
              regexp => [  'watch\?v=(?<id>(\w|-)+)&?',
                           'data-video-ids="(?<id>(\w|-)+)"',
                        ],
              url    => 'http://www.youtube.com/results?search_query={search}&page={page}',
          }
        ];
    },
);

#------------------------------------------------------------------------------------------------
use Data::Random     qw/rand_set/;
use List::MoreUtils  qw/uniq/;
use LWP::Simple      qw/get/;
use PCW::Core::Utils qw/readfile/;

use Coro;
our $lock = Coro::Semaphore->new;
#------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------
sub fetch
{
    my ($self, $engine, $task, $video_conf) = @_;
    my $vid_mode = '_'. $video_conf->{mode} . '_vid';
    croak sprintf "Video mode '%s' doesn't exist!\n", $video_conf->{mode}
        unless exists &{ $vid_mode };

    $self->load($engine,$task,$video_conf) unless $self->loaded;

    my $function = \&{ $vid_mode };
    return &$function($self, $engine, $task, $video_conf);
}

sub load
{
    my ($self, $engine, $task, $video_conf) =  @_;

    $lock->down;
    if ($video_conf->{mode} =~ /file/)
    {
        $self->video_list([ split /\s+/, readfile($video_conf->{path}) ]);
    }
    elsif ($video_conf->{mode} eq 'posts')
    {
        my @vid_list;
        $engine->log->msg('DATA_LOADING', "Start fetching video ID's from $video_conf->{type}..");
        my $raw;
        for my $query (@{ $video_conf->{search}})
        {
            for my $page (1..$video_conf->{pages})
            {
                my $url = $self->hosters->{ $video_conf->{type} }->{url};
                $url =~ s/\{search\}/$query/e;
                $url =~ s/\{page\}/$page/e;
                $raw .= LWP::Simple::get($url);
                $engine->log->msg('DATA_FOUND', "ID's were fetched from $page page and with '$query' query.");
            }
        }
        for my $pattern (@{ $self->hosters->{ $video_conf->{type} }->regexp })
        {
            while ($raw =~ /$pattern/mg)
            {
                push @vid_list, $+{id};
            }
        }
        @vid_list = uniq @vid_list;
        $engine->log->msg('DATA_LOADED', "Fetched ". scalar(@vid_list) ." video ID's");
        if (my $path = $video_conf->{save})
        {
            open(my $fh, '>', $path);
            print $fh "@vid_list";
            close $fh;
            $engine->log->msg('VIDEO_SAVED', "Video ID's saved to $path");
        }
        $self->video_list(\@vid_list);
    }
    $video_conf->{loaded} = 1;
    $lock->up;
}
#------------------------------------------------------------------------------------------------
# Internal functions
#------------------------------------------------------------------------------------------------
sub _file_vid
{
    my ($self, undef, $task, $video_conf) = @_;
    return if defined $task->{test};

    state $i = 0;

    my $video;
    if ($video_conf->{order} eq 'random')
    {
        $video = ${ rand_set(set => $self->video_list) };
    }
    elsif ($video_conf->{order} eq 'normal')
    {
        my @vid_list = @{ $self->video_list };
        $i = 0 if ($i >= scalar @vid_list);
        $video = $vid_list[$i++];
    }

    return $video;
}

sub _download_vid
{
    _file_vid(@_);
}

1;
