package Genome::Model::Tools::Vcf::Convert::Indel::Samtools;

use strict;
use warnings;
use Genome;

class Genome::Model::Tools::Vcf::Convert::Indel::Samtools {
    is => 'Genome::Model::Tools::Vcf::Convert::Base',
    doc => 'Generate a VCF file from Samtools indel output'
};

sub help_synopsis {
    <<'HELP';
    Generate a VCF file from samtools indel output
HELP
}

sub help_detail {
    <<'HELP';
    Parses the input file and creates a VCF containing all the indels.
HELP
}

sub source {
    my $self = shift;
    return "Samtools";
}

sub parse_line {
    my $self = shift;
    my $lines = shift;

    my @lines = split "\n", $lines;

    my @first_line = split "\t", $lines[0];

    my @second_line = split "\t", $lines[1];

    my $ref = $first_line[2];

    my $chr = $second_line[0];
    my $pos = $second_line[1];
    my $leading_base = $ref;
    my $indel_string = $second_line[3];
    my $consensus_quality = $second_line[4];
    my $ref_quality = $second_line[5];
    my $mapping_quality = $second_line[6];
    my $read_depth = $second_line[7];
    my $indel_call_1 = $second_line[8];
    my $indel_call_2 = $second_line[9];
    my $allele_depth_1 = $second_line[10];
    my $allele_depth_2 = $second_line[11];

    my @alt_alleles;
    my $alt_allele;
    my $ref_allele;
  
    if ($indel_call_1 ne '*') {
        push(@alt_alleles, $indel_call_1);
    }
    if ($indel_call_2 ne '*') {
        push(@alt_alleles, $indel_call_2);
    }
    if (@alt_alleles == 0) {
        die $self->error_message("No indel calls were made on this line: $indel_call_1/$indel_call_2");
    }

    #Assumption: if there are two alternate alleles, they are either both
    #insertions or both deletions.
    if ($alt_alleles[0] =~m/\+/) { #insertion
        $alt_allele = $leading_base.substr($alt_alleles[0],1);
        if (defined $alt_alleles[1]) {
            $alt_allele .= ','.$leading_base.substr($alt_alleles[1],1);
        }
        $ref_allele = $leading_base;
    }
    elsif ($alt_alleles[0] =~m/-/) { #deletion
        $alt_allele = $leading_base;

        #If there are two or more deletions, we want the longer one as the
        #ref allele
        if (defined $alt_alleles[1]) {
            my $length_difference = abs(length($alt_alleles[0]) - length($alt_alleles[1]));
            if (length($alt_alleles[0]) > length($alt_alleles[1])) {
                $ref_allele = $leading_base.substr($alt_alleles[0],1);
                $alt_allele .= ','.$leading_base.substr($alt_alleles[1], 1);
            }
            else {
                $ref_allele = $leading_base.substr($alt_alleles[1],1);
                $alt_allele .= ','.$leading_base.substr($alt_alleles[0], 1);
            }
        }
        else {
            $ref_allele = $leading_base.substr($alt_alleles[0],1);
        }
    }
    else {
        die $self->error_message("Insertion/deletion type not recognized: ".$alt_alleles[0]);
    }

    #TODO this is turned off for now because it interferes with applying filters (bed coordinates will be different once left shifted)
    # ($chr, $pos, $ref_allele, $alt_allele) = $self->normalize_indel_location($chr, $pos, $ref_allele, $alt_allele);
    
    my $GT;
    my @indel_string_split = split(/\//, $indel_string);
    if (@indel_string_split != 2) {
        $self->warning_message("Genotype in unexpected format: $indel_string at chr $chr pos $pos");
        return;
    }
    if ($indel_string eq "*/*") {
        $GT = "0/0";
    }
    elsif ($indel_string =~/\*/){
        $GT = "0/1";
    }
    elsif ($indel_string_split[0] eq $indel_string_split[1]) {
        $GT = "1/1";
    }
    else {
        $GT = "1/2";
    }

    my $DP = $read_depth;
    my $MQ = $mapping_quality;

    my $filter = "PASS";

    my $dbsnp_id = ".";
    my $qual = ".";
    my $info = ".";

    my $format = "GT:DP:MQ";
    my $sample_string = join (":", ($GT,$DP,$MQ));
    my $vcf_line = join("\t", $chr, $pos, $dbsnp_id, $ref_allele, $alt_allele, $qual, $filter,
                        $info, $format, $sample_string);
    return $vcf_line;
}

sub get_record {
    my $self = shift;
    my $input_fh = shift;

    #For samtools indel, we need to get two lines at a time.
    my $lines;
    my $line1 = $input_fh->getline; 
    my $line2;
    my $num_lines = 1;
    while ($line1 && $num_lines < 2) { 
        $line2 = $input_fh->getline;

        #Check to make sure the lines are correctly paired
        if ($line2) {
            my @fields1 = split (/\t/, $line1);
            my @fields2 = split (/\t/, $line2);
            if (($fields1[0] eq $fields2[0]) && ($fields1[1] eq $fields2[1])) {
                $lines = $line1.$line2;
                $num_lines++;
            }
            else {
                $line1 = $line2;
            }
        }
        else { #The file ended, so we couldn't get line2
            return undef;
        }
    }

    return $lines;
}

1;

