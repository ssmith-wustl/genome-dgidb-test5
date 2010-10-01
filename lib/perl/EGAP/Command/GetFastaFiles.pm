package EGAP::Command::GetFastaFiles;

use strict;
use warnings;

use EGAP;

use Bio::SeqIO;
use Bio::Seq;

use Carp 'confess';
use File::Path 'make_path';

class EGAP::Command::GetFastaFiles {
    is => 'EGAP::Command',
    has => [
        contigs_file => {
            is => 'Path',
            is_input => 1,
            doc => 'Path to a fasta file containing contigs',
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

    my $output_directory = $self->output_directory;
    unless (-d $output_directory) {
        my $mkdir_rv = make_path($output_directory);
        confess "Could not make directory at $output_directory" unless $mkdir_rv;
    }

    my $contigs_file = $self->contigs_file;
    unless (-e $contigs_file and -s $contigs_file) {
        confess "Contgs file at $contigs_file either doesn't exist or has no size!";
    }

    my $split_command = EGAP::Command::SplitFasta->create(
        fasta_file => $contigs_file,
        output_directory => $output_directory,
        max_bases_per_file => $self->max_bases_per_file,
    );
    confess "Could not create split fasta command object!" unless $split_command;

    my $split_rv = $split_command->execute;
    confess "Trouble executing split fasta command!" unless $split_rv;

    my @filenames = $split_command->fasta_files;

    $self->status_message("Created " . scalar @filenames . " split fasta files in $output_directory.");
    $self->fasta_files(\@filenames);

    return 1;
}
 
1;
