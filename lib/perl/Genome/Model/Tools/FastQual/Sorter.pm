package Genome::Model::Tools::FastQual::Sorter;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';

class Genome::Model::Tools::FastQual::Sorter {
    is  => 'Genome::Model::Tools::FastQual',
    is_abstract => 1,
};

sub help_brief {
    return <<HELP
    Sort fastq and fasta/quality sequences
HELP
}

1;

