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

# fill all of these in the subclasses

sub help_detail { 
    return <<EOS
EOS
}

sub doc_manual {
    return <<EOS
EOS
}

sub doc_copyright_years {
    return (2010, 2011);
}

sub doc_authors {
    return <<EOS
EOS
}

1;

