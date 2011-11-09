package Genome::Model::Tools::Vcf::Convert::Indel::Bed;

use strict;
use warnings;
use Genome;
use Genome::Info::IUB;

class Genome::Model::Tools::Vcf::Convert::Indel::Bed {
    is => 'Genome::Model::Tools::Vcf::Convert::Base',
    doc => 'Generate a VCF file from a bed file of indels'
};

sub help_synopsis {
    <<'HELP';
    Generate a VCF file from a bed file of indels
HELP
}

sub help_detail {
    <<'HELP';
    Parses the input file and creates a VCF containing all the indels.
HELP
}

sub source {
    my $self = shift;
    return "Bed";
}

sub parse_line {
    my $self = shift;
    my $line = shift;

    my ($chr, $pos1, $pos2, $alleles) = split("\t", $line);
    my ($ref, $alt) = split("/", $alleles);

    my $reference_allele = $self->get_base_at_position($chr, $pos1);
    if ($ref eq "0") { #insertion
        $ref = $reference_allele;
        $alt = $ref.$alt;
    }
    elsif ($alt eq "0") {#deletion
        $alt = $reference_allele;
        $ref = $alt.$ref;
    }
    else {
        die("Indel type not recognized\n");
    }
    
    my $id = ".";
    my $qual = ".";
    my $filter = "PASS";
    my $info = "TYPE=1";
    my $format = "GT";
    my $sample = "1";

    my $vcf_line = join("\t", $chr, $pos1, $id, $ref, $alt, $qual, $filter, $info, $format, $sample);

    return $vcf_line;
}

