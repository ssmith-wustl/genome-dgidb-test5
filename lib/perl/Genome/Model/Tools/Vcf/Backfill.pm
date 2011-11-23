package Genome::Model::Tools::Vcf::Backfill;

use strict;
use warnings;
use Genome;
use Sort::Naturally;

class Genome::Model::Tools::Vcf::Backfill{
    is => 'Command',
    has_input => [
        output_file => {
            is => 'Text',
            is_output => 1,
            doc => "Output backfilled VCF",
        },
        pileup_file => {
            is => 'Text',
            doc => "Input mpileup file for this sample",
        },
        vcf_file => {
            is => 'Text',
            doc => "Input vcf file for this sample to be backfilled",
        },
        use_bgzip => {
            is => 'Boolean',
            doc => 'Expect pileup (but not VCF) input in bgzip format and bgzips the output',
            default => 0,
        },
    ],
    doc => "Backfill a single sample VCF with reference information from mpileup",
};


sub help_synopsis {
    <<'HELP';
Backfill a single sample VCF with reference information from mpileup,
HELP
}

sub execute {
    my $self = shift;

    my ($mpileup_fh, $output_fh);
    if ($self->use_bgzip) {
        $mpileup_fh = Genome::Sys->open_gzip_file_for_reading($self->pileup_file);
        $output_fh = Genome::Sys->open_gzip_file_for_writing($self->output_file);
    } else {
        $mpileup_fh = Genome::Sys->open_file_for_reading($self->pileup_file);
        $output_fh = Genome::Sys->open_file_for_writing($self->output_file);
    }
    my $vcf_fh = Genome::Sys->open_gzip_file_for_reading($self->vcf_file);

    # Copy the header from the input vcf to the output vcf
    my $header_copied = 0;
    while (!$header_copied) {
        my $header_line = $vcf_fh->getline;
        if($header_line=~ m/^##/){
            $output_fh->print($header_line);
        } elsif( $header_line =~ m/^#CHROM/){
            $output_fh->print($header_line);
            $header_copied = 1;
        }
    }

    # Loop through both files and interleave the lines into the output... for now drop any pileup lines that intersect with a position the vcf already has
    my $pileup_line = $mpileup_fh->getline;
    my $vcf_line = $vcf_fh->getline;
    while( $vcf_line && $pileup_line ){
        my ($pileup_chrom,$pileup_pos) = split /\t/, $pileup_line;
        my ($vcf_chrom,$vcf_pos) = split /\t/, $vcf_line;
        my $comparison = $self->compare($pileup_chrom,$pileup_pos,$vcf_chrom,$vcf_pos);
        # The vcf file is ahead. Formulate and print VCF lines for the pileup line and advance the pileup filehandle 
        if($comparison == -1){
            my $new_vcf_line = $self->create_vcf_line_from_pileup($pileup_line);
            if ($new_vcf_line) {
                $output_fh->print("$new_vcf_line\n");
            }
            $pileup_line = $mpileup_fh->getline;
        # The pileup file is ahead. Print the VCF line to output and advance the vcf filehandle 
        } elsif ($comparison == 1) {
            $output_fh->print($vcf_line);
            $vcf_line = $vcf_fh->getline;
        # They are both at the same position. Print the VCF line as is and advance both filehandles # TODO should we always throw away pileup information here?
        } else {
            $output_fh->print($vcf_line);
            $pileup_line = $mpileup_fh->getline;
            $vcf_line = $vcf_fh->getline;
        }
    }

    # Print the remaining line from the previous loop
    if ($vcf_line) {
        $output_fh->print($vcf_line);
    } elsif ($pileup_line) {
        my $new_vcf_line = $self->create_vcf_line_from_pileup($pileup_line);
        $output_fh->print("$new_vcf_line\n");
    }

    # Finish off whichever file is not done
    while (my $pileup_line = $mpileup_fh->getline) {
        my $new_vcf_line = $self->create_vcf_line_from_pileup($pileup_line);
        $output_fh->print("$new_vcf_line\n");
    }
    while (my $vcf_line = $vcf_fh->getline) {
        $output_fh->print($vcf_line);
    }

    return 1;
}

# Given a pileup line, return a vcf line containing the reference information
sub create_vcf_line_from_pileup {
    my $self = shift;
    my $pileup_line = shift;

    chomp $pileup_line;
    my ($chr, $pos, $ref, $genotype, $gq, $vaq, $mq, $dp, $read_bases, $base_qualities) = split("\t", $pileup_line);

    # Ignore insertions and deletions
    if ($ref eq "*") {
        return;
    }

    # Parse the pileup and quality strings so that they have the same length and can be mapped to one another
    if ($read_bases =~ m/[\$\^\+-]/) {
        $read_bases =~ s/\^.//g; #removing the start of the read segment mark
        $read_bases =~ s/\$//g; #removing end of the read segment mark
        while ($read_bases =~ m/[\+-]{1}(\d+)/g) {
            my $indel_len = $1;
            $read_bases =~ s/[\+-]{1}$indel_len.{$indel_len}//; # remove indel info from read base field
        }
    }
    if ( length($read_bases) != length($base_qualities) ) {
        die $self->error_message("After processing, read base string and base quality string do not have identical lengths: $read_bases $base_qualities\nLine: $pileup_line");
    }

    # Count the number of times the variant occurs in the pileup string (AD) and its quality from the quality string (BQ)
    my @bases = split("", $read_bases);
    my @qualities = split("", $base_qualities);
    my $ad = 0;
    my $bq_total = 0;
    for (my $index = 0; $index < scalar(@bases); $index++) {
        my $base = $bases[$index];
        if ($base eq "," || $base eq ".") { # If the base matches ref on + or - strand
            #http://samtools.sourceforge.net/pileup.shtml base quality is the same as mapping quality
            $ad++;
            $bq_total += ord($qualities[$index]) - 33;
        }
    }

    # Get an average of the quality for BQ
    my $bq;
    if ($ad == 0) {
        $bq = 0;
    } else {
        $bq = int($bq_total / $ad);
    }

    my %depth_hash;
    $depth_hash{'GQ'}= $gq;
    $depth_hash{'BQ'}= $bq;
    $depth_hash{'MQ'}= $mq;
    $depth_hash{'DP'}= $dp;
    $depth_hash{'AD'}= $ad;
    $depth_hash{'GT'}= "0/0";

    my $format_tags = join ":", qw(GT GQ DP BQ MQ AD);
    my @tags = split ":", $format_tags;
    my @output;
    for my $tag (@tags) {
        my $value = $depth_hash{$tag} || ".";
        push @output, $value;
    }
    my $sample_string = join ":", @output;

    my $id = ".";
    my $alt = ".";
    my $qual = ".";
    my $info = ".";
    my $filter = "."; 
    my $new_vcf_line = join "\t", ($chr, $pos, $id, $ref, $alt, $qual, $filter, $info, $format_tags, $sample_string); 

    return $new_vcf_line;
}

#return -1 if $chr_a,$pos_a represents a lower position than $chr_b,$pos_b, 0 if they are the same, and 1 if b is lower
sub compare {
    my $self = shift;
    my ($chr_a,$pos_a,$chr_b,$pos_b) = @_;
    if(($chr_a eq $chr_b) && ($pos_a == $pos_b)){
        return 0;
    }
    if($chr_a eq $chr_b){
        return ($pos_a < $pos_b) ? -1 : 1;
    }
    return ($self->chr_cmp($chr_a,$chr_b)) ? 1 : -1;
}

# return 0 if $chr_a is lower than $chr_b, 1 otherwise
sub chr_cmp {
    my $self = shift;
    my ($chr_a, $chr_b) = @_;
    my @chroms = ($chr_a,$chr_b);
    my @answer = nsort @chroms;
    return ($answer[0] eq $chr_a) ? 0 : 1;
}

1;
