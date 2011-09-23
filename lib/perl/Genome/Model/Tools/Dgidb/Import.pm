package Genome::Model::Tools::Dgidb::Import;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::Dgidb::Import {
    is => 'Genome::Model::Tools::Dgidb',
    has => [],
};

sub help_brief {
#TODO: write me
    #'Create unfiltered bed file from Dbsnp flat files'
}

sub help_synopsis {
    return <<EOS
gmt dgidb import ...
EOS
}

sub help_detail {
#TODO: write me
    return <<EOS
This command doesn't do anything yet, and needs to be written
EOS
}

1;
