package Genome::Model::Tools::Vcf;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::Vcf {
    is => ['Command'],
};

sub help_brief {
    "Tools and scripts to create and manipulate VCF files."
}

sub help_detail {
    return <<EOS
Tools and scripts to create and manipulate VCF files.
EOS
}

1;
