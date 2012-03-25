package PCW::Data::Video;

use strict;
use Carp;
use autodie;
use feature qw/state switch say/;

use Exporter 'import';
our @EXPORT_OK = qw(make_vid);

#------------------------------------------------------------------------------------------------
use Data::Random qw(rand_set);
use LWP::Simple qw(get);

use Coro;
my $lock = Coro::Semaphore->new;

#------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------
my %types = ( youtube => ['watch\?v=(?<id>(\w|-)+)&?',
                         ],
            );

my %search_urls = ( youtube => 'http://www.youtube.com/results?search_query={search}&page={page}');

sub make_vid($)
{
    my $conf = shift;
    my $vid_mode = $conf->{mode} . '_vid';
    Carp::croak sprintf "Video mode '%s' doesn't exist!\n", $conf->{mode}
			unless exists &{ $vid_mode };
    my $get_vid = \&{ $vid_mode };
    return &$get_vid($conf);
}

#------------------------------------------------------------------------------------------------
sub file_vid($)
{
    my $data = shift;

    state @vid_list;

    $lock->down;
    if (!@vid_list)
    {
        open(my $fh, '<', $data->{path});
		local $/ = undef;
        my $raw  = <$fh>;
        close $fh;

        for my $pattern (@{ $types{ $data->{type} } })
        {
             while ($raw =~ /$pattern/mg)
            {
                push @vid_list, $+{id};
            }
        }
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

sub download_vid($)
{
    my $data = shift;
    state @vid_list;

    $lock->down;
    if (!@vid_list)
    {
        my $raw;
        for my $page (1..$data->{pages})
        {
            my $url = $search_urls{ $data->{type} };
            $url =~ s/\{search\}/$data->{search}/e;
            $url =~ s/\{page\}/$page/e;
            $raw .= get($url);
            say "$url downloaded";
        }
        for my $pattern (@{ $types{ $data->{type} } })
        {
            while ($raw =~ /$pattern/mg)
            {
                push @vid_list, $+{id};
            }
        }
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

1;
