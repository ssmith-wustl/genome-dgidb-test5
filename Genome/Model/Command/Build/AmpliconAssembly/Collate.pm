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

    my $amplicons = $self->build->get_amplicons
        or return;

    $self->_open_collating_fhs
        or return;

    for my $amplicon ( @$amplicons ) {
        if ( $amplicon->get_bioseq ) {
            $self->{_fasta_writer}->write_seq($amplicon->get_bioseq);
            $self->{_qual_writer}->write_seq($amplicon->get_bioseq);
        }
        $self->_collate_amplicon_fasta_and_qual($amplicon);
    }

    $self->_close_collating_fhs;

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
    my $fasta_file = $self->build->assembly_fasta;
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
        my $fasta_file = $self->build->$file_method;
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

#< Collating the Amplicon Fastas >#
sub _collate_amplicon_fasta_and_qual {
    my ($self, $amplicon) = @_;

    for my $type ( keys %pre_assembly_fasta_and_qual_types ) {
        # FASTA
        my $fasta_file = sprintf(
            $pre_assembly_fasta_and_qual_types{$type}, $self->build->edit_dir, $amplicon->get_name, 
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
            sprintf('No contigs qual file (%s) for amplicon (%s)', $qual_file, $amplicon->get_name)
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

1;

#$HeadURL$
#$Id$
