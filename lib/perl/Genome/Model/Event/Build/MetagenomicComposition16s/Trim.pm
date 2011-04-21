package Genome::Model::Event::Build::MetagenomicComposition16s::Trim;

use strict;
use warnings;

use Genome;

class Genome::Model::Event::Build::MetagenomicComposition16s::Trim {
    is => 'Genome::Model::Event::Build::MetagenomicComposition16s',
    is_abstract => 1,
};

sub _add_amplicon_reads_fasta_and_qual_to_build_processed_fasta_and_qual {
    my ($self, $fasta_file, $qual_file) = @_;

    # Write the 'raw' read fastas
    my $reader = Genome::Model::Tools::FastQual::PhredReader->create(
        files => [ $fasta_file, $qual_file ],
    );
    return if not $reader;
    while ( my $seqs = $reader->read ) {
        $self->_processed_reads_fasta_and_qual_writer->write($seqs)
            or return;
    }
 
    return 1;
}

sub _processed_reads_fasta_and_qual_writer {
    my $self = shift;

    unless ( $self->{_processed_reads_fasta_and_qual_writer} ) {
        my $fasta_file = $self->build->processed_reads_fasta_file;
        unlink $fasta_file if -e $fasta_file;
        my $qual_file = $self->build->processed_reads_qual_file;
        unlink  $qual_file if -e $qual_file;
        my $writer = Genome::Model::Tools::FastQual::PhredWriter->create(files => [ $fasta_file, $qual_file ]);
        return if not $writer;
        $self->{_processed_reads_fasta_and_qual_writer} = $writer;
    }

    return $self->{_processed_reads_fasta_and_qual_writer};
}

1;

