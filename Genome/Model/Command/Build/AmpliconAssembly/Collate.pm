package Genome::Model::Command::Build::AmpliconAssembly::Collate;

use strict;
use warnings;

use Genome;

use Bio::Seq::Quality;
use Bio::SeqIO;
use Data::Dumper;
use File::Grep 'fgrep';
require Finishing::Assembly::Factory;
require GD::Graph::lines;
require Genome::Utility::FileSystem;
require IO::File;

class Genome::Model::Command::Build::AmpliconAssembly::Collate {
    is => 'Genome::Model::Event',
};

#< Subclassing...don't >#
sub _get_sub_command_class_name {
  return __PACKAGE__;
}

#< LSF >#
sub bsub_rusage {
    return "";
}

#< Beef >#
sub execute {
    my $self = shift;

    my $amplicons = $self->model->amplicons
        or return;

    $self->_open_collating_fhs
        or return;

    while ( my ($amplicon) = each %$amplicons ) {
        $self->_collate_assembly($amplicon);
        $self->_collate_amplicon_fasta_and_qual($amplicon);
    }

    unless ( $self->{_metrix}->{assemblies_assembled} ) {
        $self->error_message( sprintf('<== No assemblies for %s ==>', $self->model->name) );
        return;
    }

    $self->_close_collating_fhs;
    $self->status_message( sprintf('<== Assembly Fasta: %s ==>', $self->model->assembly_fasta) );
    $self->status_message( sprintf('<== Assembly Qual %s.qual ==>', $self->model->assembly_fasta) );
    $self->_create_report;

    return 1;
}

#< FHs >#
my %pre_assembly_fasta_and_qual_types = (
    reads => '%s/%s.reads.fasta', 
    processed => '%s/%s.fasta',
);
sub _open_collating_fhs {
    my $self = shift;

    # Assemblies
    my $fasta_file = $self->model->assembly_fasta;
    unlink $fasta_file if -e $fasta_file;
    $self->{_fasta_writer} = Bio::SeqIO->new(
        '-file' => ">$fasta_file",
        '-format' => 'Fasta',
    )
        or return; # this should die
    my $qual_file = $fasta_file.'.qual';
    unlink $qual_file if -e $qual_file;
    $self->{_qual_writer} = Bio::SeqIO->new(
        '-file' => ">$qual_file",
        '-format' => 'qual',
    )
        or return; # this should die
    
    # Pre assembly fastas and quals
    for my $type ( keys %pre_assembly_fasta_and_qual_types ) {
        my $file_method = sprintf('%s_fasta', $type);
        my $fasta_file = $self->model->$file_method;
        unlink $fasta_file if -e $fasta_file;
        $self->{ sprintf('_%s_fasta_fh', $type) } = Genome::Utility::FileSystem->open_file_for_writing($fasta_file)
            or return;

        my $qual_file = $fasta_file . '.qual';
        unlink $qual_file if -e $qual_file;
        $self->{ sprintf('_%s_qual_fh', $type) } = Genome::Utility::FileSystem->open_file_for_writing($qual_file)
            or return;
    }

    return 1;
}

sub _close_collating_fhs {
    my $self = shift;

    for my $type ( keys %pre_assembly_fasta_and_qual_types ) {
        $self->{ sprintf('_%s_fasta_fh', $type) }->close;
        $self->{ sprintf('_%s_qual_fh', $type) }->close;
    }

    return 1;
}

#< Collating Assembly >#
sub _collate_assembly {
    my ($self, $amplicon) = @_;

    $self->{_metrix}->{assemblies_attempted}++;

    # Check contigs file to see if an assembly was generated
    my $bioseq;
    if ( -s sprintf('%s/%s.fasta.contigs', $self->model->edit_dir, $amplicon) ) {
        # Get fasta/qual from contig from assembly / Calc metrics
        $bioseq = $self->_get_bioseq_from_longest_contig($amplicon);
    }
    else {
        # Get fasta/qual from largest read
        $bioseq = $self->_get_bioseq_from_longest_read($amplicon);
    }
    return unless $bioseq; # there are valid reasons we won't have a bioseq here

    # write out fasta/qual
    $self->{_fasta_writer}->write_seq($bioseq);
    $self->{_qual_writer}->write_seq($bioseq);

    return 1;
}

sub _get_bioseq_from_longest_contig {
    my ($self, $amplicon) = @_;

    #< Determine longest contig >#
    my $acefile = sprintf('%s/%s.fasta.ace', $self->model->edit_dir, $amplicon);
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
    my $reads_attempted = fgrep { /phd/ } sprintf('%s/%s.phds', $self->model->edit_dir, $amplicon);
    unless ( $reads_attempted ) {
        $self->error_message(
            sprintf('No attempted reads in phds file (%s/%s.phds)', $self->model->edit_dir, $amplicon)
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
        '-id' => $amplicon,
        '-desc' => sprintf('source=contig reads=%s', $reads->count), 
        '-seq' => $contig->unpadded_base_string,
        '-qual' => join(' ', @{$contig->qualities}),
    );
}

sub _get_bioseq_from_longest_read {
    my ($self, $amplicon) = @_;

    #< Determine longest read for amplicon >#
    # fasta
    my $fasta_file = sprintf('%s/%s.fasta', $self->model->edit_dir, $amplicon);
    return unless -s $fasta_file;
    my $fasta_reader = Bio::SeqIO->new(
        '-file' => $fasta_file,
        '-format' => 'Fasta',
    )
        or return;
    my $longest_fasta = $fasta_reader->next_seq;
    while ( my $seq = $fasta_reader->next_seq ) {
        $longest_fasta = $seq if $seq->length > $longest_fasta->length;
    }

    unless ( $longest_fasta ) { # should never happen
        $self->error_message( 
            sprintf(
                'Found fasta file for amplicon (%s) reads, but could not find the longest fasta',
                $amplicon,
            ) 
        );
        return;
    }

    # qual
    my $qual_file = sprintf('%s/%s.fasta.qual', $self->model->edit_dir, $amplicon);
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
                'Found largest fasta for amplicon (%s), but could not find corresponding qual with id (%s)',
                $amplicon,
                $longest_fasta->id,
            ) 
        );
        return;
    }

    #< Bioseq >#
    my $bioseq = Bio::Seq::Quality->new(
        '-id' => $amplicon,
        '-desc' => sprintf('source=%s reads=1', $longest_fasta->id),
        '-seq' => $longest_fasta->seq,
        '-qual' => $longest_qual->qual,
    );

    return $bioseq;
}

#< Collating the Amplicon Fastas >#
sub _collate_amplicon_fasta_and_qual {
    my ($self, $amplicon) = @_;

    for my $type ( keys %pre_assembly_fasta_and_qual_types ) {
        # FASTA
        my $fasta_file = sprintf(
            $pre_assembly_fasta_and_qual_types{$type}, $self->model->edit_dir, $amplicon, 
        );
        next unless -s $fasta_file;
        my $fasta_fh = IO::File->new($fasta_file, 'r')
            or $self->fatal_msg("Can't open file ($fasta_file) for reading");
        my $fasta_fh_key = sprintf('_%s_fasta_fh', $type);
        while ( my $line = $fasta_fh->getline ) {
            $self->{$fasta_fh_key}->print($line);
        }
        $self->{$fasta_fh_key}->print("\n");

        #QUAL
        my $qual_file = sprintf('%s.qual', $fasta_file);
        $self->fatal_msg(
            sprintf('No contigs qual file (%s) for amplicon (%s)', $qual_file, $amplicon)
        ) unless -e $qual_file;
        my $qual_fh = IO::File->new("< $qual_file")
            or $self->fatal_msg("Can't open file ($qual_file) for reading");
        my $qual_fh_key = sprintf('_%s_qual_fh', $type);
        while ( my $line = $qual_fh->getline ) {
            $self->{$qual_fh_key}->print($line);
        }
        $self->{$qual_fh_key}->print("\n");
    }

    return 1;
}

#< Reporting >#
sub _create_report {
    my $self = shift;

    my $totals = $self->_calculate_totals;

    my $file = $self->model->metrics_file;
    unlink $file if -e $file;
    my $fh = Genome::Utility::FileSystem->open_file_for_writing($file, 'w')
        or return;

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

#$HeadURL$
#$Id$
