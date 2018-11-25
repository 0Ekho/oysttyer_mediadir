
=encoding utf8

=pod LICENSE

 BSD-0
 Copyright (C) 2018, Ekho <ekho@ekho,email>

 Permission to use, copy, modify, and/or distribute this software for any
 purpose with or without fee is hereby granted.

 THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

 ------------------------------------------------------------------------------

=cut

=head4

 saves attached media from tweets to a media directory
 media directory can be set by adding
    extpref_mediadir=/full/path/to/dir
 to your .oystterrc file, avoid adding trailing slashes
 else the mediadir defaults to
    ~/.local/share/twitter_media

=cut

# -----------------------------------------------------------------------------

#use strict;
use warnings;
use utf8;

use File::Basename qw(basename);
use File::Path qw(make_path);

#binmode(STDOUT, ":utf8");
#binmode(STDIN, ":encoding(UTF-8)");

# -----------------------------------------------------------------------------
# constants
use constant {
    VERSION_STRING_MD => '0.0.1-alpha',
    DEFAULT_MEDIADIR => "$ENV{'HOME'}/.local/share/oysttyer_media"
};

# -----------------------------------------------------------------------------

sub save_media;

# -----------------------------------------------------------------------------
# setup #

print("** mediadir plugin loaded\n");

if (defined $extpref_mediadir) {
    $store->{'mediadir'} = $extpref_mediadir;
} else {
    print("** extpref_mediadir not set, falling back to default\n");
    $store->{'mediadir'} = DEFAULT_MEDIADIR;
}
if (defined $extpref_mediadir_debug) {
    $store->{'mediadir_debug'} = $extpref_mediadir_debug
} else {
    $store->{'mediadir_debug'} = 0;
}

print("** mediadir is set to '$store->{'mediadir'}'\n");

if (not -e $store->{'mediadir'}) {
    print("** mediadir does not exist, creating...\n");
    make_path($store->{'mediadir'});
} elsif (not -d $store->{'mediadir'}) {
    &$screech("*** Mediadir is not a directory, aborting!");
}

# -----------------------------------------------------------------------------

$handle = sub {
    my $ref = shift;

    # Twitter API-compliant applications are required to check for this
    # if protected user preform default and return without saving media
    if (exists $ref->{'user'} and exists $ref->{'user'}->{'protected'} and
        $ref->{'user'}->{'protected'} eq 'true') {
        &defaulthandle($ref);
        return 1;
    }

    #if ($store->{'mediadir_debug'} >= 5) {
    #        use Data::Dumper;
    #        print("***DEBUG: ENTIRE hashref dump: \n");
    #        print(Dumper($ref));
    #}

    # TODO: make this cleaner
    my $is_rt = 0;
    if (not exists $ref->{'extended_entities'}->{'media'} or
        not defined $ref->{'extended_entities'}->{'media'}[0]->{type}) {
        if (not exists $ref->{'retweeted_status'}->{'extended_entities'}->
            {'media'} or not defined $ref->{'retweeted_status'}->
            {'extended_entities'}->{'media'}[0]->{type}) {
            &defaulthandle($ref);
            return 1;
        } else {
            $is_rt = 1;
        }
    }

    my $ee;
    if ($is_rt == 1) {
        if ($store->{'mediadir_debug'} >= 2) {
            print("***DEBUG: EE set from retweeted_status\n");
        }
        $ee = $ref->{'retweeted_status'}->{'extended_entities'};
    } else {
        $ee = $ref->{'extended_entities'}; 
    }

    my $type = $ee->{'media'}[0]->{type};
    if ($store->{'mediadir_debug'} >= 2) {
        print("***DEBUG: EEMEDIA with type '$type' found\n");
    }

    if ($type eq 'photo') {
        foreach (@{$ee->{'media'}}) {
            save_media($_->{'media_url_https'} . ':orig');
        }
    } elsif ($type eq 'video') {
        my $br = 0;
        foreach (@{$ee->{'media'}[0]->{'video_info'}->{'variants'}}) {
            if (exists $_->{'bitrate'} and $_->{'bitrate'} > $br) {
                $br = $_->{'bitrate'};
            }
        }
        foreach (@{$ee->{'media'}[0]->{'video_info'}->{'variants'}}) {
            if (exists $_->{'bitrate'} and $_->{'bitrate'} == $br) {
                save_media($_->{'url'});
                last;
            }
        }
        save_media($ee->{'media'}[0]->{'media_url_https'});
    } elsif ($type eq 'animated_gif') {
        save_media($ee->{'media'}[0]->{'media_url_https'});
        save_media($ee->{'media'}[0]->{'video_info'}->{'variants'}[0]->{'url'});
    }

    &defaulthandle($ref);
    return 1;
};

# -----------------------------------------------------------------------------

sub save_media {
    my $url = shift;

    # remove the backslashes from url
    $url =~ s/\\\//\//g;

    my $f = basename($url);
    # remove junk from filenames
    $f =~ s/:orig$|\?tag=[0-9]+$//;

    # file already has been saved
    if (-e "$store->{'mediadir'}/$f") {
        return 0;
    }
    if ($store->{'mediadir_debug'} >= 1) {
        print("***DEBUG: saving '$url'\n");
    }
    # TODO: make limit-rate configurable
    system('curl', '--silent', '--limit-rate', '200K', '--output',
        "$store->{'mediadir'}/$f", "$url");
    # may be unable to save the media, say if deleted between reciving the
    # tweet and the tweet finishing being parsed / the handle being called
    # or if the connection times out
    if (($? >> 8) > 0) {
        print("** unable to save '$url'\n");
    }
    return 1;
}
