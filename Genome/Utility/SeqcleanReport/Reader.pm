package Genome::Utility::SeqCleanReport::Reader;

use strict;
use warnings;

use above "Genome";

my @header_fields = qw(accession pc_undetermined start end length trash_code comments);

class Genome::Utility::SeqCleanReport::Reader {
    is => 'Genome::Utility::Parser',
    has => [
            separator => {
                          default_value => "\t",
                      },
            header => {
                       default_value => '0',
                   },
            ],
};

sub header_fields {
    return \@header_fields;
}


1;
