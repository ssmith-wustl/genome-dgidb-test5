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

}

sub doc_copyright_years {
    return (2010, 2011);
}

sub doc_copyright_licenese {

}

sub doc_authors {

}

1;

