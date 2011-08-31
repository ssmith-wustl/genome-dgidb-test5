package Genome::Model::Tools::Vcf::Convert::Snv::Samtools;

use strict;
use warnings;
use Genome;
use Genome::Info::IUB;

class Genome::Model::Tools::Vcf::Convert::Snv::Samtools {
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

    # TODO VAQ should technically be math with both cons and snp quality, or perhaps a new calculation?
    my ($chr, $pos, $ref, $genotype, $gq, $vaq, $mq, $dp, $read_bases, $base_quality) = split("\t", $line);

    #replace ambiguous/IUPAC bases with N in ref
    $ref =~ s/[^ACGTN\-]/N/g;

    my @alt_alleles = Genome::Info::IUB->variant_alleles_for_iub($ref, $genotype);
    my @alleles = Genome::Info::IUB->iub_to_alleles($genotype);
    my $alt = join(",", @alt_alleles);

    #add the ref and alt alleles' positions in the allele array to the GT field
    my $gt = $self->generate_gt($ref, \@alt_alleles, \@alleles);

    # Parse the pileup and quality strings
    if ($read_bases =~ m/[\$\^\+-]/) {
        $read_bases =~ s/\^.//g; #removing the start of the read segement mark
        $read_bases =~ s/\$//g; #removing end of the read segment mark
        while ($read_bases =~ m/[\+-]{1}(\d+)/g) {
            my $indel_len = $1;
            $read_bases =~ s/[\+-]{1}$indel_len.{$indel_len}//; # remove indel info from read base field
        }
    }
    my (%ad, %bq_total);
    my ($bq_string, $ad_string);
    if ( length($read_bases) != length($base_quality) ) {
        die $self->error_message("After processing, read base string and base quality string do not have identical lengths: $read_bases $base_quality");
    } else {
        my @bases = split("", $read_bases);
        my @qualities = split("", $base_quality);
        for (my $index = 0; $index < scalar(@bases); $index++) {
            my $base = uc($bases[$index]);
            for my $variant (@alt_alleles) {
                if ($variant eq $base) {
                    $ad{$variant}++;
                    $bq_total{$variant} += ord($qualities[$index]); 
                }
            }
        }

        my %bq;
        for my $variant (@alt_alleles) {
            if ($ad{$variant}) {
                $bq{$variant} = int($bq_total{$variant} / $ad{$variant});
            } else {
                $bq{$variant} = 0;
                $ad{$variant} = 0;
            }
        }
        $bq_string = join ",", map { $bq{$_} } @alt_alleles;
        # Count the number of times the variant occurs in the pileup string (if there is more than one variant, this should be adjusted)
        $ad_string = join ",", map { $ad{$_} } @alt_alleles;
    }

    # fraction of reads supporting alt
    my $total_ad;
    map { $total_ad += $ad{$_} } keys %ad;
    my $fa = $total_ad / $dp; 
    $fa = sprintf "%.3f", $fa; # Round to 3 decimal places since we dont have that many significant digits

    # Placeholder for later adjustment
    my $dbsnp_id = ".";
    my $qual = $vaq;
    my $filter = "PASS";
    my $format = "GT:GQ:DP:BQ:MQ:AD:FA:VAQ";
    my $info = ".";
    my $sample_string = join (":", ($gt, $gq, $dp, $bq_string, $mq, $ad_string, $fa, $vaq));

    my $vcf_line = join("\t", $chr, $pos, $dbsnp_id, $ref, $alt, $qual, $filter, $info, $format, $sample_string);

    return $vcf_line;
}

