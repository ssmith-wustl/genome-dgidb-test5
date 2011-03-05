package Genome::Model::Tools::Music::Base;

use strict;
use warnings;
use Genome;

our $VERSION = $Genome::Model::Tools::Music::VERSION;

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

sub doc_copyright_licenese {
    # once license, following the main module
    return Genome::Model::Tools::Music->doc_copyright_license();    
}

# fill all of these in the subclasses

sub help_detail { 
    return <<EOS
EOS
}

sub doc_manual {
    # POD to go into man pages, but not help
    return <<EOS
EOS
}

sub doc_copyright_years {
    # used to compose man pages
    return (2010, 2011);
}

sub doc_authors {
    # used to compose man pages 
    # (return a list of strings)
    return;
}

1;

