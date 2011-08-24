package Genome::Model::Tools::Vcf::Convert::Indel;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::Vcf::Convert::Indel {
    is => ['Command'],
};

sub help_brief {
    "Tools to convert lists of indels to VCF files."
}

sub help_detail {
    return <<EOS
Tools to convert lists of indels to VCF files.
EOS
}

1;
