package Genome::Model::Tools::Vcf::Convert::Snv::Sniper;

use strict;
use warnings;
use Genome;
use Genome::Info::IUB;

class Genome::Model::Tools::Vcf::Convert::Snv::Sniper {
    is => 'Genome::Model::Tools::Vcf::Convert::Base',
    doc => 'Generate a VCF file from sniper output'
};

sub help_synopsis {
    <<'HELP';
    Generate a VCF file from sniper snv output
HELP
}

sub help_detail {
    <<'HELP';
    Parses the input file and creates a VCF containing all the snvs.
HELP
}

sub parse_line {
    my $self = shift;
    my $line = shift;

    # TODO snv_qual is not used...
    my ($chr, $pos, $ref, $genotype, $tumor_vaq, $snv_qual, $tumor_mq, $tumor_bq, $tumor_dp, $normal_dp ) = split("\t",$line);
    my $tumor_gq = $tumor_mq; #TODO Should these really be the same?

    #replace ambiguous/IUPAC bases with N in ref
    $ref =~ s/[^ACGTN\-]/N/g;

    my @alt_alleles = Genome::Info::IUB->variant_alleles_for_iub($ref, $genotype);
    my @alleles = Genome::Info::IUB->iub_to_alleles($genotype);
    my $alt = join(",", @alt_alleles);

    #add the ref and alt alleles' positions in the allele array to the GT field
    my $tumor_gt = $self->generate_gt($ref, \@alt_alleles, \@alleles);

    # We do not have access to much of the normal information from somatic output
    my $normal_gt = ".";
    #genotype quality (consensus quality)
    my $normal_gq = ".";
    # avg mapping quality ref/var
    my $normal_mq = ".";
    # avg mapping quality ref/var
    my $normal_bq = ".";
    # allele depth
    my $normal_ad =  ".";
    my $tumor_ad =  ".";
    # fraction of reads supporting alt
    my $normal_fa =  ".";
    my $tumor_fa =  ".";
    # vaq
    my $normal_vaq = ".";

    # Placeholder for later adjustment
    my $dbsnp_id = ".";
    my $qual = "."; # Can also be $tumor_vaq
    my $filter = "PASS";
    my $format = "GT:GQ:DP:BQ:MQ:AD:FA:VAQ";
    my $info = "VT=SNP"; # Can also just be .
    my $tumor_sample_string = join (":", ($tumor_gt, $tumor_gq, $tumor_dp, $tumor_bq, $tumor_mq, $tumor_ad, $tumor_fa, $tumor_vaq));
    my $normal_sample_string = join (":", ($normal_gt, $normal_gq, $normal_dp, $normal_bq, $normal_mq, $normal_ad, $normal_fa, $normal_vaq));

    my $vcf_line = join("\t", $chr, $pos, $dbsnp_id, $ref, $alt, $qual, $filter, $info, $format, $normal_sample_string, $tumor_sample_string);

    return $vcf_line;
}

