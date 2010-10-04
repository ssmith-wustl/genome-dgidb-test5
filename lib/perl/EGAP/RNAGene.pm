package EGAP::RNAGene;

use strict;
use warnings;

use EGAP;
use Bio::SeqIO;
use Carp 'confess';

class EGAP::RNAGene {
    type_name => 'rna gene',
    schema_name => 'files',
    data_source => 'EGAP::DataSource::RNAGenes',
    id_by => [
        gene_name => { is => 'Text' },
    ],
    has => [
        data_directory => { is => 'Path' },
        description => { is => 'Text' },
        start => { is => 'Number' },
        end => { is => 'Number' },
        strand => { is => 'Number' },
        source => { is => 'Text' },
        score => { is => 'Number' },
        sequence_id => { is => 'Number' },
    ],
};

# TODO Should fasta file be stored on the object for later lookups? Or perhaps the sequence itself should be
# stored? I'm concerned that might bloat the file, but it might be worthwhile if sequence lookups happen a lot.
sub sequence {
    my ($self, $fasta_file) = @_;
    confess "No sequence fasta found at $fasta_file" unless -e $fasta_file;
    
    my $fasta = Bio::SeqIO->new(
        -file => $fasta_file,
        -format => 'Fasta',
    );

    my $seq_obj;
    while ($seq_obj = $fasta->next_seq) {
        last if $seq_obj->display_id eq $self->gene_name();
    }

    my $seq = $seq_obj->seq();
    $self->warning_message("No sequence found for sequence " . $self->gene_name()) unless length $seq > 0;
    return $seq;
}

1;
