package Genome::Model::Tools::Vcf::Convert::Snv::Samtools;

use strict;
use warnings;
use Genome;
use POSIX 'strftime';
use Genome::Info::IUB;

class Genome::Model::Tools::Vcf::Convert::Snv::Samtools {
    is => 'Genome::Model::Tools::Vcf::Convert::Base',
    doc => 'Generate a VCF file from samtools output'
};

sub help_synopsis {
    <<'HELP';
    Generate a VCF file from samtools snv output
HELP
}

sub help_detail {
    <<'HELP';
    Parses the input file and creates a VCF containing all the snvs.
HELP
}

sub source {
    my $self = shift;
    return "Samtools";
}

sub _get_header_columns {
    my $self = shift;
    my @header_columns = ("CHROM","POS","ID","REF","ALT","QUAL","FILTER","INFO","FORMAT",$self->aligned_reads_sample);
    return @header_columns;
}

sub print_header {
    my $self = shift;
    my $input_file = $self->input_file;

    my $token = `head -1 $input_file`;

    if ($token =~ /^#/) {  #mpileup
        my (@header, @new_header);
        my $input_fh = $self->_input_fh;
        while (my $line = $input_fh->getline) {
            push @header, $line if $line =~ /^#/;
        }
        $input_fh->close;

        #reintialized the file handle to be used next step
        my $new_fh = Genome::Sys->open_file_for_reading($input_file) or die "Failed to open $input_file\n";
        $self->_input_fh($new_fh); 

        while (@header) {
            last if $header[0] =~ /^##INFO/; #split original vcf header
            push @new_header, shift @header;
        }

        my @extra_info  = $self->_extra_header_info;
        push @new_header, @extra_info, @header;
        
        my $output_fh = $self->_output_fh;
        map{$output_fh->print($_)}@new_header;
    }
    else { #pileup
        return $self->SUPER::print_header;
    }

    return 1;
}

sub _extra_header_info {
    my $self = shift;
    my $date = strftime("%Y%m%d", localtime);
    my $source     = $self->source;
    my $public_ref = $self->_get_public_ref;

    return ("##fileDate=$date\n", "##source=$source\n", "##reference=$public_ref\n", "##phasing=none\n");
}


sub parse_line {
    my ($self, $line) = @_;
    return if $line =~ /^#/; # no mpileup vcf header here
    my @columns = split("\t", $line);

    if ($columns[4] =~ /^[A-Z]+/) { #mpileup output vcf format already
        $columns[6] = 'PASS';
        my $new_line = join "\t", @columns;
        return $new_line;
    }

    my ($chr, $pos, $ref, $genotype, $gq, $vaq, $mq, $dp, $read_bases, $base_quality) = @columns;
    #replace ambiguous/IUPAC bases with N in ref
    $ref =~ s/[^ACGTN\-]/N/g;

    my @alt_alleles = Genome::Info::IUB->variant_alleles_for_iub($ref, $genotype);
    my @alleles = Genome::Info::IUB->iub_to_alleles($genotype);
    my $alt = join(",", @alt_alleles);

    #add the ref and alt alleles' positions in the allele array to the GT field
    my $gt = $self->generate_gt($ref, \@alt_alleles, \@alleles);

    # Parse the pileup and quality strings so that they have the same length and can be mapped to one another
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
    }

    # Count the number of times the variant occurs in the pileup string (AD) and its quality from the quality string (BQ)
    my @bases = split("", $read_bases);
    my @qualities = split("", $base_quality);
    for (my $index = 0; $index < scalar(@bases); $index++) {
        my $base = uc($bases[$index]);
        for my $variant (@alt_alleles) {
            if ($variant eq $base) {
                $ad{$variant}++;
                #http://samtools.sourceforge.net/pileup.shtml base quality is the same as mapping quality
                $bq_total{$variant} += ord($qualities[$index]) - 33; 
            }
        }
    }

    # Get an average of the quality for BQ
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
    $ad_string = join ",", map { $ad{$_} } @alt_alleles;

    # fraction of reads supporting alt
    my $total_ad;
    map { $total_ad += $ad{$_} } keys %ad;
    my $fa = $total_ad / $dp; 
    $fa = sprintf "%.3f", $fa; # Round to 3 decimal places since we dont have that many significant digits

    # If the variant called is N, just null out the GT and FET fields to minimize interference with cross-sample VCFs
    if ($genotype eq "N") {
        $gt = ".";
        $alt = ".";
        $ad_string = ".";
        $bq_string = ".";
        $fa = ".";
    }

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

