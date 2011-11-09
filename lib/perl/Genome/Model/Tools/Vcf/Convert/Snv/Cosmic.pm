package Genome::Model::Tools::Vcf::Convert::Snv::Cosmic;

use strict;
use warnings;
use Genome;
#use Shell;

class Genome::Model::Tools::Vcf::Convert::Snv::Cosmic {
    is => 'Genome::Model::Tools::Vcf::Convert::Base',
    doc => 'Generate a VCF file from a cosmic file of variants (may be snvs or indels)'
};

sub help_synopsis {
    <<'HELP';
    Generate a VCF file from a cosmic file of variants (may be snvs or indels)
HELP
}

sub help_detail {
    <<'HELP';
    Parses the input file and creates a VCF containing all the snvs and indels.
HELP
}

sub source {
    my $self = shift;
    return "Cosmic";
}

sub parse_line {
    my $self = shift;
    my $line = shift;

    my @fields = split(/\t/, $line);
    my $cDNA = $fields[2];
    my $reference;
    my $variant;

    #extract positions
    my ($chr, $start, $end);
    if ($fields[6]) {
        ($chr, $start, $end) = split /[:-]/,$fields[6];
    }

    unless(defined $chr && defined $start && defined $end) {
        print STDERR "No build37 coordinates found for: $line\n";
        return 0;
    }

    if ($chr eq "23") {
        $chr = "X";
    }

    if($cDNA =~ /c.\d+([+-]\d+)*(_\d+([+-]\d+)*)*ins[ACTG]+/) {
        $reference = $self->get_base_at_position($chr, $start-1);
        ($variant) = $cDNA =~ /\d+ins([ACTG]+)/;
        $variant = $reference.$variant;
    }
    elsif($cDNA =~ /c.\d+([+-]\d+)*(_\d+([+-]\d+)*)*del[ACTG]+/) {
        ($reference) = $cDNA =~ /\d+del([ACTG]+)/;
        $variant = $self->get_base_at_position($chr, $start-1);
        #check strand
        my $out = `samtools faidx /gscmnt/sata420/info/model_data/2857786885/build102671028/all_sequences.fa $chr:$start-$end`;
        chomp $out;
        my @lines = split(/\n/, $out);
        if ($reference ne $lines[1]) {
            $reference = reverse($reference);
            $reference =~ tr/ACGT/TGCA/;
            if ($reference ne $lines[1]){
                print STDERR "Not equal del $reference ".$lines[1]." $line\n";
                return 0;
            }
        }
        $reference = $variant.$reference;
        $start--;
    }
    elsif($cDNA =~ /\d+\D>\D/) {
        ($reference,$variant) = $cDNA =~ /(\D)>(\D)/;
        if ($end - $start + 1 != length($variant)) {
            print STDERR "Variant coordinates don't correspond to variant\n";
            return 0;
        }
        if (!($variant =~ m/[ACGT]/)) {
            print STDERR "Variant not ACGT\n";
            return 0;
        }
        #check strand
        my $out = `samtools faidx /gscmnt/sata420/info/model_data/2857786885/build102671028/all_sequences.fa $chr:$start-$end`;
        chomp $out;
        my @lines = split(/\n/, $out);
        if ($reference ne $lines[1]) {
            $reference = reverse($reference);
            $variant = reverse($variant);
            $reference =~ tr/ACGT/TGCA/;
            $variant =~ tr/ACGT/TGCA/;
            if ($reference ne $lines[1]){
                print STDERR "Not equal $reference ".$lines[1]." $line\n";
                return 0;
            }
        }
    }
    else {
        print STDERR "Unable to extract alleles for $line\n";
        return 0;
    }

    if ($reference eq $variant) {
        print STDERR "Reference and allele are equal: $reference/$variant\n";
        return 0;
    }

    my $id = ".";
    my $qual = ".";
    my $filter = "PASS";
    my $info = "TYPE=1";
    my $format = "GT";
    my $sample = "1";

    my $vcf_line = join("\t", $chr, $start, $id, $reference, $variant, $qual, $filter, $info, $format, $sample);

    return $vcf_line;
}

