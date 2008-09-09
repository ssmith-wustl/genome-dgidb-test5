package Genome::Utility::454TrimFile::Reader;

use strict;
use warnings;

use Genome;

my @header_fields = qw(accession start end);

class Genome::Utility::454TrimFile::Reader {
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
