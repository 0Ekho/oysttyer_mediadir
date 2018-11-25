# oysttyer mediadir

oysttyer extension to automatically save twitter media attachments to a directory.

## Usage
set ```extpref_mediadir=/full/path/to/dir``` in your ```.oystterrc``` file, then load the
extension as normal

## Drawbacks / Known issues
* the media file is downloaded before displaying the tweet, with larger files like video this may
make the tweets delayed on slower connections
* there is also the risk of never catching up on slower connections with media heavy feeds, not
sure what will happen after some time in this case.
* it also uses what may be a noticable amount of disk space after a while 
(~200 follow, >30GB/mo), if you run out this will error (or maybe crash?)
* currently if there is an issue with the download nothing is done, this may lead to some of the
downloaded file being left empty or corrupt if the download fails (killed, internet drops, etc)
