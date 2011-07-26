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
        my ($chr,$start,$id, $ref,$var,$qual, $filter, $info, $genotype_keys, @genotype_values) = split("\t", $line);
        my $stop;
        my @keys = split ":", $genotype_keys;

        # There will be one set of values per sample. Add up the total depth and average the total score.
        my $depth;
        my $running_score;
        my $samples_with_data;
        for my $genotype_value (@genotype_values) {
            my @values = split ":", $genotype_value;
            if (scalar @keys == scalar @values) {
                $samples_with_data++;
            } else {
                next;
            }
            

            my %genotype_hash;
            for my $key (@keys) {
                $genotype_hash{$key} = shift @values;
            }
            # Score will sometimes be floating point and we don't want that
            $running_score += $genotype_hash{GQ};
            $depth += $genotype_hash{DP};
        }
        if (!defined $depth) {
            $depth = 0;
        }
        my $score;
        if (defined $running_score) {
            $score = int( $running_score / $samples_with_data );
        } else {
            $score = 0;
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
