package EGAP::Command::GetFastaFiles;

use strict;
use warnings;

use EGAP;

use Bio::SeqIO;
use Bio::Seq;

use Carp 'confess';
use File::Path 'make_path';
use POSIX 'ceil';

class EGAP::Command::GetFastaFiles {
    is => 'EGAP::Command',
    has => [
        seq_set_id => { 
            is => 'Number',
            is_input => 1,
            doc => 'Identifies an assembly in the EGAP database',
        },
        output_directory => {
            is => 'Path',
            is_input => 1,
            doc => 'All split fastas are put in this directory',
        },
    ],
    has_optional => [
        max_bases_per_file => {
            is => 'Number',
            is_input => 1,
            default => 5000000,
            doc => 'Each split fasta should contain approximately this number of bases of sequence each',
        },
        fasta_files => { 
            is => 'ARRAY',
            is_output => 1,
            doc => 'Array of fasta files each containing a single contig from assembly',
        },

    ],
};

sub help_brief {
    return "Splits up an assembly into several smaller fastas";
}

sub help_synopsis {
    return "Splits up an assembly into several smaller fastas";
}

sub help_detail {
    return <<EOS
A given assembly (currently grabbed using the sequence set id, but this will change soon) is split up
into several smaller fastas (by either supercontig or contig), where each fasta file contains no more
than the given number bases.
EOS
}

sub execute {
    my $self = shift;

    $DB::single = 1;
    my $output_directory = $self->output_directory;
    unless (-d $output_directory) {
        my $mkdir_rv = make_path($output_directory);
        confess "Could not make directory at $output_directory" unless $mkdir_rv;
    }

    my $seq_set_id = $self->seq_set_id;
    my $sequence_set = EGAP::SequenceSet->get($seq_set_id);
    my @sequences = $sequence_set->sequences();

    $self->status_message("Found " . scalar @sequences . " contigs in database, dumping into a temporary fasta file.");

    # TODO Need to create a temporary fasta file that can be split up into smaller chunks.
    # This file can be removed after the smaller fastas are made. Once EGAP data is file-based,
    # this step won't be necessary (though I guess some sort of conversion might be).
    my $temp_fasta_path = "$output_directory/temp_fasta.fa";
    my $temp_fasta = Bio::SeqIO->new(
        -file => ">$temp_fasta_path",
        -format => 'Fasta',
    );

    for my $sequence (@sequences) {
        my $contig = Bio::Seq->new(
            -seq => $sequence->sequence_string(),
            -id => $sequence->sequence_name(),
        );
        $temp_fasta->write_seq($contig);
    }
    $temp_fasta->close;

    $self->status_message("Temporary fasta created at $temp_fasta_path, sequences written, now splitting.");

    my $split_command = EGAP::Command::SplitFasta->create(
        fasta_file => $temp_fasta_path,
        output_directory => $output_directory,
        max_bases_per_file => $self->max_bases_per_file,
    );
    confess "Could not create split fasta command object!" unless $split_command;

    my $split_rv = $split_command->execute;
    confess "Trouble executing split fasta command!" unless $split_rv;

    my @filenames = $split_command->fasta_files;

    unlink $temp_fasta_path;

    $self->status_message("Created " . scalar @filenames . " split fasta files in $output_directory.");
    $self->fasta_files(\@filenames);

    return 1;
}
 
1;
