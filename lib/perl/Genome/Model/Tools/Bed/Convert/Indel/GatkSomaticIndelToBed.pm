package Genome::Model::Tools::Bed::Convert::Indel::GatkSomaticIndelToBed;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::Bed::Convert::Indel::GatkSomaticIndelToBed {
    is => ['Genome::Model::Tools::Bed::Convert::Indel'],
    has => [
        reference_sequence_input => {
            is => 'String',
            default=> Genome::Config::reference_sequence_directory() . '/NCBI-human-build36/all_sequences.fa',
            doc => "The reference fasta file used to look up the reference sequence with samtools faidx. This is necessary because pindel will truncate long reference sequences.",
        },
    ],
};


sub process_source {
    my $self = shift;
    
    my $input_fh = $self->_input_fh;
    
    while(my $line = $input_fh->getline) {
        my ($chr,$start,$stop, $refvar) = split("\t", $line);
        my ($ref, $var, $type);
        if ($refvar =~ m/\-/) {
            $type = '-';
        }
        else {
            $type = '+';
        }
        $refvar =~ s/[\+,\-]//;
        if ($type eq '+') {
            $ref = '0';
            $var = $refvar;
        }
        else {
            $var = '0';
            $ref = $refvar;
        }
        $self->write_bed_line($chr, $start, $stop, $ref, $var);
    }
    $input_fh->close;
    return 1;
}

1;
