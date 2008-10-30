package Genome::Model::Command::MetaGenomicComposition::CollateFasta::Assembled;

use strict;
use warnings;

use Genome;

require Bio::SeqIO;
use Data::Dumper;

class Genome::Model::Command::MetaGenomicComposition::CollateFasta::Assembled { 
    is => 'Genome::Model::Command::MetaGenomicComposition',
    has_optional => [
    get_largest_contig_only => {
        type => 'Boolean',
        default => 0,
        doc => 'Get the largest contig FATA and Qual for a given subclone assembly',
    },
    ],
};

sub help_brief {
    return 'Collate the FASTAs and Quality files for all assemblies in a MGC model.';
}

sub help_detail {
    return help_brief();
}

sub execute {
    my $self = shift;

    my $subclones = $self->model->subclones
        or return;

    $self->_create_bioseq_outputs
        or return;
    
    for my $subclone ( @$subclones ) {
        $self->_add_fasta_and_qual($subclone)
            or return;
    }

    return 1;
}

sub _create_bioseq_outputs {
    my $self = shift;

    my $fasta_file = $self->model->all_assembled_fasta;
    unlink $fasta_file if -e $fasta_file;
    my $fasta_out = Bio::SeqIO->new(
        '-format' => 'Fasta',
        '-file' => "> $fasta_file",
    )
        or return;
    $self->{_fasta_output} = $fasta_out;

    my $qual_file = $fasta_file . '.qual';
    unlink $qual_file if -e $qual_file;
    my $qual_out = Bio::SeqIO->new(
        '-format' => 'qual',
        '-file' => "> $qual_file",
    )
        or return;
    $self->{_qual_output} = $qual_out;

    return 1;
}

sub fasta_output {
    return $_[0]->{_fasta_output};
}

sub qual_output {
    return $_[0]->{_qual_output};
}

sub _add_fasta_and_qual {
    my ($self, $subclone) = @_;

    # FASTA
    my $fasta_file = sprintf('%s/%s.fasta.contigs', $self->model->consed_directory->edit_dir, $subclone);
    return 1 unless -s $fasta_file;
    my $fasta_in = Bio::SeqIO->new(
        '-format' => 'Fasta',
        '-file' => $fasta_file,
    )
        or return;
    my $largest_fasta = $fasta_in->next_seq;
    while ( my $fasta = $fasta_in->next_seq ) {
        next unless $fasta->length > $largest_fasta->length;
        $largest_fasta = $fasta;
    }
    $self->fasta_output->write_seq($largest_fasta);

    #QUAL
    my $qual_file = sprintf('%s.qual', $fasta_file);
    $self->fatal_msg(
        sprintf('No contigs qual file (%s) for subclone (%s)', $qual_file, $subclone)
    ) unless -e $qual_file;
    my $qual_in = Bio::SeqIO->new(
        '-format' => 'qual',
        '-file' => $qual_file,
    )
        or return;
    my $qual_written;
    while ( my $qual = $qual_in->next_seq ) {
        next unless $qual->id eq $largest_fasta->id;
        $self->qual_output->write_seq($qual);
        $qual_written++;
        last;
    }

    unless ( $qual_written ) {
        $self->error_message( sprintf('Can\'t find qual for fasta (%s)', $largest_fasta->id) );
        return;
    }

    return 1;
}

1;

=pod

=head1 Disclaimer

Copyright (C) 2007 Washington University Genome Sequencing Center

This script is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=head1 Author(s)

B<Eddie Belter> <ebelter@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$
