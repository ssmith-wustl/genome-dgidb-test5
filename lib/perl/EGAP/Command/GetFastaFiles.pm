package EGAP::Command::GetFastaFiles;

use strict;
use warnings;

use EGAP;

use Bio::SeqIO;
use Bio::Seq;

use Carp qw(confess);
use File::Path qw(make_path);

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
        fasta_files => { 
            is => 'ARRAY',
            is_output => 1,
            doc => 'Array of fasta files each containing a single contig from assembly',
        },

    ],
};

sub help_brief {
    "Write a set of fasta files for an assembly";
}

sub help_synopsis {
    return <<"EOS"
    egap get-fasta-files --seq-set-id 12345
EOS
}

sub help_detail {
    return <<"EOS"
Need documenation here.
EOS
}

sub execute {
    my $self = shift;

    my $output_directory = $self->output_directory;
    unless (-d $output_directory) {
        my $mkdir_rv = make_path($output_directory);
        confess "Could not make directory at $output_directory" unless $mkdir_rv;
    }

    my $seq_set_id = $self->seq_set_id;
    my $sequence_set = EGAP::SequenceSet->get($seq_set_id);
    my @sequences = $sequence_set->sequences();

    $self->status_message("Found " . scalar @sequences . " contigs in database");

    my @filenames;
    my $current_fasta;
    my $counter = 0;

    for my $sequence (@sequences) {
        my $length = length $sequence->sequence_string();
        next unless $length >= 20000;

        my $contig = Bio::Seq->new(
            -seq => $sequence->sequence_string(),
            -id => $sequence->sequence_name(),
        );

        my $filename = $output_directory . "/fasta_$counter.fa";
        $current_fasta = Bio::SeqIO->new(
            -file => ">$filename",
            -format => 'Fasta',
        );

        $current_fasta->write_seq($contig);
        push @filenames, $filename;
        $counter++;

        # TODO Testing only
        #last if @filenames > 5;
        last;
    }

    $self->status_message("Created " . scalar @filenames . " split fasta files:\n" . join("\n", @filenames));
    $self->fasta_files(\@filenames);
    return 1;
}
 
1;
