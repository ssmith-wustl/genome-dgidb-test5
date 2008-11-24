package Genome::Model::Command::MetaGenomicComposition::CollateAssemblies;

use strict;
use warnings;

use Genome;

use Bio::Seq::Quality;
use Bio::SeqIO;
use Data::Dumper;
require Finishing::Assembly::Factory;
require GD::Graph::lines;
require IO::File;
use File::Grep 'fgrep';
      
class Genome::Model::Command::MetaGenomicComposition::CollateAssemblies {
    is => 'Genome::Model::Command::MetaGenomicComposition',
};

sub execute {
    my $self = shift;

    $self->_verify_mgc_model
        or return;
    
    my $templates = $self->model->subclones_and_traces_for_assembly
        or return;
    
    my $fasta_file = $self->model->all_assembled_fasta;
    unlink $fasta_file if -e $fasta_file;
    my $fasta_writer = Bio::SeqIO->new(
        '-file' => ">$fasta_file",
        '-format' => 'Fasta',
    )
        or return;
    my $qual_file = $fasta_file.'.qual';
    unlink $qual_file if -e $qual_file;
    my $qual_writer = Bio::SeqIO->new(
        '-file' => ">$qual_file",
        '-format' => 'qual',
    )
        or return;
    
    while ( my ($subclone) = each %$templates) {
        $self->{_metrix}->{assemblies_attempted}++;
        # Check contigs file to see if an assembly was generated
        my $bioseq;
        if ( -s sprintf('%s/%s.fasta.contigs', $self->model->consed_directory->edit_dir, $subclone) ) {
            # Get fasta/qual from contig from assembly / Calc metrics
            $bioseq = $self->_get_bioseq_from_longest_contig($subclone);
        }
        else {
            # Get fasta/qual from largest read
            $bioseq = $self->_get_bioseq_from_longest_read($subclone);
        }
        next unless $bioseq; # there are valid reasons we won't have a bioseq here

        # write out fasta/qual
        $fasta_writer->write_seq($bioseq);
        $qual_writer->write_seq($bioseq);
    }

    unless ( $self->{_metrix}->{assemblies_assembled} ) {
        $self->status_message( sprintf('<== No assemblies for %s ==>', $self->model->name) );
        return 1;
    }

    #print Dumper($self->{_metrix});
    $self->status_message("<== All Assembled Fasta: $fasta_file ==>");
    $self->status_message("<== All Assembled Qual: $qual_file ==>");
    $self->_create_report;

    return 1;
}

sub _get_bioseq_from_longest_contig {
    my ($self, $subclone) = @_;

    #< Determine longest contig >#
    my $acefile = sprintf('%s/%s.fasta.ace', $self->model->consed_directory->edit_dir, $subclone);
    my $factory = Finishing::Assembly::Factory->connect('ace', $acefile);
    my $contigs = $factory->get_assembly->contigs;
    my $contig = $contigs->first
        or return;
    while ( my $ctg = $contigs->next ) {
        next unless $ctg->reads->count > 1;
        $contig = $ctg if $ctg->unpadded_length > $contig->unpadded_length;
    }
    # Need to have at least one read
    my $reads = $contig->reads;
    my $reads_assembled = $reads->count;
    return unless $reads_assembled > 1;

    #< Metrics >#
    # Lengths
    $self->{_metrix}->{lengths_total} += $contig->unpadded_length;
    push @{ $self->{_metrix}->{lengths} }, $contig->unpadded_length;
    $self->{_metrix}->{assemblies_assembled}++;

    # Reads
    $self->{_metrix}->{reads_assembled_total} += $reads->count;
    push @{ $self->{_metrix}->{reads_assembled} }, $reads->count;
    my $reads_attempted = fgrep { /phd/ } sprintf('%s/%s.phds', $self->model->consed_directory->edit_dir, $subclone);
    unless ( $reads_attempted ) {
        $self->error_message(
            sprintf('No attempted reads in phds file (%s/%s.phds)', $self->model->consed_directory->edit_dir, $subclone)
        );
        return;
    }
    $self->{_metrix}->{reads_attempted_total} += $reads_attempted;
    push @{ $self->{_metrix}->{reads_attempted} }, $reads_attempted;

    # Get quals
    my $qual_total = 0;
    my $qual20_bases = 0;
    for my $qual ( @{$contig->qualities} ) { 
        $qual_total += $qual;
        $qual20_bases++ if $qual >= 20;
    }

    $self->{_metrix}->{bases_qual_total} += $qual_total;
    $self->{_metrix}->{bases_greater_than_qual20} += $qual20_bases;

    $factory->disconnect;

    #< Bioseq >#
    return Bio::Seq::Quality->new(
        '-id' => $subclone,
        '-desc' => sprintf('source=contig reads=%s', $reads->count), 
        '-seq' => $contig->base_string,
        '-qual' => join(' ', @{$contig->qualities}),
    );
}

sub _get_bioseq_from_longest_read {
    my ($self, $subclone) = @_;

    #< Determine longest read for subclone >#
    # fasta
    my $fasta_file = sprintf('%s/%s.fasta', $self->model->consed_directory->edit_dir, $subclone);
    my $fasta_reader = Bio::SeqIO->new(
        '-file' => $fasta_file,
        '-format' => 'Fasta',
    )
        or return;
    my $longest_fasta;
    while ( my $seq = $fasta_reader->next_seq ) {
        unless ( $longest_fasta ) {
            $longest_fasta = $seq;
            next;
        }
        $longest_fasta = $seq if $seq->length > $longest_fasta->length;
    }

    unless ( $longest_fasta ) { # should never happen
        $self->error_message( 
            sprintf(
                'Found fasta file for subclone (%s) reads, but could not find a fasta',
                $subclone,
            ) 
        );
        return;
    }

    # qual
    my $qual_file = sprintf('%s/%s.fasta.qual', $self->model->consed_directory->edit_dir, $subclone);
    my $qual_reader = Bio::SeqIO->new(
        '-file' => $qual_file,
        '-format' => 'qual',
    )
        or return;
    my $longest_qual;
    while ( my $seq = $qual_reader->next_seq ) {
        next unless $seq->id eq $longest_fasta->id;
        $longest_qual = $seq;
        last;
    }

    unless ( $longest_qual ) {
        $self->error_message( 
            sprintf(
                'Found largest fasta for subclone (%s), but could not find corresponding qual with id (%s)',
                $subclone,
                $longest_fasta->id,
            ) 
        );
        return;
    }

    #< Bioseq >#
    my $bioseq = Bio::Seq::Quality->new(
        '-id' => $subclone,
        '-desc' => sprintf('source=%s reads=1', $longest_fasta->id),
        '-seq' => $longest_fasta->seq,
        '-qual' => $longest_qual->qual,
    );

    return $bioseq;
}

sub _create_report {
    my $self = shift;

    my $totals = $self->_calculate_totals;

    my $file = $self->model->metrics_file;
    unlink $file if -e $file;
    my $fh = IO::File->new($file, 'w');
    unless ( $fh ) { 
        $self->error_message("Can't open file ($file): $!");
        return;
    }

    $fh->print( join(',', sort { $a cmp $b } keys %$totals) );
    $fh->print("\n");
    $fh->print( join(',', map { $totals->{$_} } sort { $a cmp $b } keys %$totals) );
    $fh->print("\n");

    $self->status_message("<== Stats report file: $file ==>");
    
    return $fh->close;
}

sub _calculate_totals {
    my $self = shift;

    my %totals;
    $totals{assemblies_assembled} = $self->{_metrix}->{assemblies_assembled};
    $totals{assemblies_attempted} = $self->{_metrix}->{assemblies_attempted};
    $totals{assemblies_assembled_pct} = sprintf(
        '%.2f', 
        100 * $self->{_metrix}->{assemblies_assembled} / $self->{_metrix}->{assemblies_attempted}
    );
    $totals{assemblies_reads_attempted} = $self->{_metrix}->{reads_attempted_total};
    $totals{assemblies_reads_assembled} = $self->{_metrix}->{reads_assembled_total};
    $totals{assemblies_reads_assembled_pct} = sprintf(
        '%.2f',
        100 * $self->{_metrix}->{reads_assembled_total} / $self->{_metrix}->{reads_attempted_total},
    );

    my @lengths = sort { $a <=> $b } @{ $self->{_metrix}->{lengths} };
    $totals{assemblies_length_min} = $lengths[0];
    $totals{assemblies_length_max} = $lengths[$#lengths];
    $totals{assemblies_length_median} = $lengths[( $#lengths / 2 )];
    $totals{assemblies_length_avg} = sprintf(
        '%.0f',
        $self->{_metrix}->{lengths_total} / $self->{_metrix}->{assemblies_assembled},
    );

    $totals{bases_qual_avg} = sprintf(
        '%.2f', 
        $self->{_metrix}->{bases_qual_total} / $self->{_metrix}->{lengths_total}
    );
    $totals{bases_greater_than_qual20_per_assembly} = sprintf(
        '%.2f',
        $self->{_metrix}->{bases_greater_than_qual20} / $self->{_metrix}->{assemblies_assembled},
    );

    my @reads = sort { $a <=> $b } @{ $self->{_metrix}->{reads_assembled} };
    $totals{reads_assembled_min} = $reads[0];
    $totals{reads_assembled_max} = $reads[$#reads];
    $totals{reads_assembled_median} = $reads[( $#reads / 2 )];
    $totals{reads_assembled_avg_per_assembly} = sprintf(
        '%.2F',
        $self->{_metrix}->{reads_assembled_total} / $self->{_metrix}->{assemblies_assembled},
    );

    return \%totals;
}

1;

=pod

=head1 Name

Modulesubclone

=head1 Synopsis

=head1 Usage

=head1 Methods

=head2 

=over

=item I<Synopsis>

=item I<Arguments>

=item I<Returns>

=back

=head1 See Also

=head1 Disclaimer

Copyright (C) 2005 - 2008 Washington University Genome Sequencing Center

This module is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=head1 Author(s)

B<Eddie Belter> I<ebelter@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$
