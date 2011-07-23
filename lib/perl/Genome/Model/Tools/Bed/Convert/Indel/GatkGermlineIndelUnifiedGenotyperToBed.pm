package Genome::Model::Tools::Bed::Convert::Indel::GatkGermlineIndelUnifiedGenotyperToBed;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::Bed::Convert::Indel::GatkGermlineIndelUnifiedGenotyperToBed {
    is => ['Genome::Model::Tools::Bed::Convert::Indel'],
};

sub process_source {
    my $self = shift;
    
    my $input_fh = $self->_input_fh;
    
    while(my $line = $input_fh->getline) {
        chomp $line;
        next if $line =~ /^#/;
        # VCF format
        my ($chr,$start,$id, $ref,$var,$qual, $filter, $info, $genotype_keys, $genotype_values) = split("\t", $line);
        my $stop;
        my @keys = split ":", $genotype_keys;
        my @values = split ":", $genotype_values;

        unless (scalar @keys == scalar @values) {
            die $self->error_message("Number of keys and values in the genotype fields did not match");
        }
        my %genotype_hash;
        for my $key (@keys) {
            $genotype_hash{$key} = shift @values;
        }
        # Score will sometimes be floating point and we don't want that
        my $score = int($genotype_hash{GQ});
        my $depth = $genotype_hash{DP};
        if (!defined $score) {
            $score = "-";
        }
        if (!defined $depth) {
            $depth = "-";
        }

        if(length($ref) == 1 and length($var) == 1) {
            #SNV case
            $stop = $start;
            $start -= 1; #convert to 0-based coordinate
        } elsif (length($ref) == 1 and length($var) > 1) {
            #insertion case
            $stop = $start; #VCF uses 1-based position of base before the insertion (which is the same as 0-based position of first inserted base), insertions have no length
            $ref = '*';
            $var = substr($var, 1);
        } elsif (length($ref) > 1 and length($var) == 1) {
            #deletion case
            $ref = substr($ref, 1);
            $stop = $start + length($ref);
            $var = '*';
        } else {
            die $self->error_message('Unhandled variant type encountered');
        }
        
        $self->write_bed_line($chr, $start, $stop, $ref, $var, $score, $depth);
    }
    $input_fh->close;
    return 1;
}

1;
