package GSCApp::MediaWiki;

use warnings;
use strict;

use base 'App::MediaWiki';



sub wiki_url {
    return 'https://gscweb.gsc.wustl.edu/wiki';
}

sub mediawiki_domain {

    my $self = shift;

    return 'gsc';
}

1;
