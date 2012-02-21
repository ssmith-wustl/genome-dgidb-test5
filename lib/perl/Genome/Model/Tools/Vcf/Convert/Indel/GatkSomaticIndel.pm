package Genome::Model::Tools::Vcf::Convert::Indel::GatkSomaticIndel;

use strict;
use warnings;
use Genome;
use File::Basename;

class Genome::Model::Tools::Vcf::Convert::Indel::GatkSomaticIndel {
    is  => 'Genome::Model::Tools::Vcf::Convert::Base',
    doc => 'Generate a VCF file from GATK somatic indel output',
};


sub help_synopsis {
    <<'HELP';
    Generate a VCF file from Gatk somatic indel output
HELP
}

sub help_detail {
    <<'HELP';
    Parses the input file and creates a VCF containing all the indels.
HELP
}

sub source {
    return 'GatkSomaticIndel';
}


#Currently GATK output a bad-formatted vcf file, need some
#modification to be standard vcf. 
sub initialize_filehandles {
    my $self = shift;

    if ($self->_input_fh || $self->_output_fh) {
        return 1; #Already initialized
    }

    my $input  = $self->input_file;
    my $output = $self->output_file;

    #GATK specific VCF output. For now modify this file since it's no
    #way to parse vcf info from original gatk_output_file due to ref
    #base before indel
    my $dir     = dirname $input;
    my $raw_vcf = $dir . '/gatk_output_file.vcf'; 

    unless (-s $raw_vcf) {
        die $self->error_message("gatk_output_file.vcf is not available under the input directory");
    }

    my $input_fh  = Genome::Sys->open_file_for_reading($raw_vcf)
        or die "Failed to open $raw_vcf for reading\n";
    my $output_fh = Genome::Sys->open_gzip_file_for_writing($output) 
        or die "Failed to open $output for writing\n";
    
    $self->_input_fh($input_fh);
    $self->_output_fh($output_fh);

    return 1;
}


sub get_format_meta {
    my $gt = {MetaType => "FORMAT", ID => "GT", Number => 1, Type => "String", Description => "Genotype"};
    my $ad = {MetaType => "FORMAT", ID => "AD", Number => "A", Type => "Integer", Description => "Indel allele depth"};
    return ($gt, $ad);
}


sub get_info_meta {
    my $end    = {MetaType => "INFO", ID => "END", Number => 1, Type => "Integer", Description => "End position of the variant described in this record"};
    my $svlen  = {MetaType => "INFO", ID => "SVLEN", Number => 1, Type => "Integer", Description => "Indel length"};
    my $svtype = {MetaType => "INFO", ID => "SVTYPE", Number => 1, Type => "String", Description => "Indel type"};
    return ($end, $svlen, $svtype);
}


sub parse_line {
    my ($self, $line) = @_;
    return if $line =~ /^#/;  #skip the header
    return unless $line =~ /SOMATIC;/; #skip non-somatic events

    my @columns = split /\s+/, $line;
    my ($n_ad, $t_ad) = $columns[7] =~ /N_AC=(\d+).*T_AC=(\d+)/;
    my ($t_gt) = $columns[9]  =~ /^(\S+):/;
    my ($n_gt) = $columns[10] =~ /^(\S+):/;
    $t_gt .= ':' . $t_ad;
    $n_gt .= ':' . $n_ad;

    my ($pos, $ref_length, $indel_length) = ($columns[1], length($columns[3]), length($columns[4]));

    my ($svtype, $end);
    my $svlen = $indel_length - $ref_length;

    if ($svlen > 0) { #insertion
        $svtype = 'INS';
        $end = $pos + 1;
    }
    elsif ($svlen < 0) {
        $svtype = 'DEL';
        $end = $pos + 1 + abs($svlen);
    }
    else { #
        die $self->error_message("$line is not valid for indel");
    }

    #Now construct new line
    $columns[6]  = 'PASS';
    $columns[7]  = "END=$end;SVLEN=$svlen;SVTYPE=$svtype";
    $columns[8]  = 'GT:AD';
    $columns[9]  = $n_gt;
    $columns[10] = $t_gt;

    my $new_line = join "\t", @columns;
    return $new_line;
}

1;

