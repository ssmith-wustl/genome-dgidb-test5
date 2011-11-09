package Genome::Model::Tools::Vcf::Convert::Snv::Bed;

use strict;
use warnings;
use Genome;
use Genome::Info::IUB;

class Genome::Model::Tools::Vcf::Convert::Snv::Bed {
    is => 'Genome::Model::Tools::Vcf::Convert::Base',
    doc => 'Generate a VCF file from a bed file of snvs'
};

sub help_synopsis {
    <<'HELP';
    Generate a VCF file from a bed file of snvs
HELP
}

sub help_detail {
    <<'HELP';
    Parses the input file and creates a VCF containing all the snvs.
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
    
    my @alt_alleles = Genome::Info::IUB->variant_alleles_for_iub($ref, $alt);
    $alt = join(",", @alt_alleles);
    
    my $id = ".";
    my $qual = ".";
    my $filter = "PASS";
    my $info = "TYPE=1";
    my $format = "GT";
    my $sample = "1";

    my $vcf_line = join("\t", $chr, $pos2, $id, $ref, $alt, $qual, $filter, $info, $format, $sample);

    return $vcf_line;
}

