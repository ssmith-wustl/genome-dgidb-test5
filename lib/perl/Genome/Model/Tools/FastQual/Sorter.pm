package Genome::Model::Tools::FastQual::Sorter;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';

class Genome::Model::Tools::FastQual::Sorter {
    is  => 'Genome::Model::Tools::FastQual',
    is_abstract => 1,
};

sub help_synopsis {
    return <<HELP
    Sort fastq sequences
HELP
}

sub help_detail {
    return <<HELP 
HELP
}

1;

