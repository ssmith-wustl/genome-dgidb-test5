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
        my ($chr,$start,undef, $ref,$var) = split("\t", $line);
        my $stop;
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
        
        $self->write_bed_line($chr, $start, $stop, $ref, $var);
    }
    $input_fh->close;
    return 1;
}

1;
