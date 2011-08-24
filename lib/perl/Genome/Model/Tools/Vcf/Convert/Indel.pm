package Genome::Model::Tools::Vcf::Convert::Indel;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::Vcf::Convert::Indel {
    is => ['Command'],
};

sub help_brief {
    "Tools and scripts to convert VCF files."
}

sub help_detail {
    return <<EOS
Tools and scripts to convert VCF files.
EOS
}

1;
