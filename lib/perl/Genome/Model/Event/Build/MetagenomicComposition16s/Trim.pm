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
    my $reader = Genome::Utility::BioPerl::FastaAndQualReader->create(
        fasta_file => $fasta_file,
        qual_file => $qual_file,
    ) or return;
    while ( my $bioseq = $reader->next_seq ) {
        $self->_processed_reads_fasta_and_qual_writer->write_seq($bioseq)
            or return;
    }
 
    return 1;
}

sub _processed_reads_fasta_and_qual_writer {
    my $self = shift;

    unless ( $self->{_processed_reads_fasta_and_qual_writer} ) {
        $self->{_processed_reads_fasta_and_qual_writer} = Genome::Utility::BioPerl::FastaAndQualWriter->create(
            fasta_file => $self->build->processed_reads_fasta_file,
            qual_file => $self->build->processed_reads_qual_file,
        )
            or return;
    }

    return $self->{_processed_reads_fasta_and_qual_writer};
}

1;

#$HeadURL$
#$Id$
