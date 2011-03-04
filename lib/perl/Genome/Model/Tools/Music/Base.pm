package Genome::Model::Tools::Music::Base;

use strict;
use warnings;
use Genome;

our $VERSION = '0.01';

class Genome::Model::Tools::Music::Base {
    is => ['Command::V2'],
    is_abstract => 1,
    attributes_have => [
        file_format => {
            is => 'Text',
            is_optional => 1,
        }
    ],
    doc => "cancer mutation analysis"
};

sub help_detail { 
    # for things without docs, we will keep this pretty
    "" 
}

sub doc_manual {
    # POD to go into man pages, but not help
    return;
}

sub doc_copyright_years {
    # used to compose man pages
    return (2010, 2011);
}

sub doc_copyright_licenese {
    # used to compose man pages
    return;
}

sub doc_authors {
    # used to compose man pages 
    # (return a list of strings)
    return;
}

1;

