package Genome::Model::Command::AddReads::MergeAlignments::Blat;

use strict;
use warnings;

use above "Genome";
use Command;
use Genome::Model;
use IO::File;


class Genome::Model::Command::AddReads::MergeAlignments::Blat {
    is => [
           'Genome::Model::Command::AddReads::MergeAlignments',
       ],
    has => [
            merged_alignments_file => {
                                      calculate_from => ['model'],
                                      calculate => q|
                                          return $model->alignments_directory .'/'. $model->sample_name .'.psl';
                                      |,
                                   },
            merged_fasta_file => {
                                  calculate_from => ['model'],
                                  calculate => q|
                                          return $model->alignments_directory .'/'. $model->sample_name .'.fa';
                                      |,
                              },
        ],
};

sub help_brief {
    "Merge all blat alignments";
}

sub help_synopsis {
    return <<"EOS"
    genome-model add-reads postprocess-alignments merge-alignments blatPlusCrossmatch --model-id 5 --ref-seq-id all_sequences
EOS
}

sub help_detail {
    return <<EOS
This command is usually called as part of the add-reads process
EOS
}


sub should_bsub { 1;}


sub execute {
    my $self = shift;

    $DB::single = 1;

    my $start = UR::Time->now;
    my $model = $self->model;

    my $alignments_dir = $model->alignments_directory;
    unless (-e $alignments_dir) {
        unless (mkdir $alignments_dir) {
            $self->error_message("Failed to create directory '$alignments_dir':  $!");
            return;
        }
    } else {
        unless (-d $alignments_dir) {
            $self->error_message("File already exist for directory '$alignments_dir':  $!");
            return;
        }
    }
                                                                           );

    my @alignment_events = $model->alignment_events;
    my @sub_alignment_files;
    for my $alignment_event (@alignment_events) {
        push @sub_alignment_files, $alignment_event->alignment_file;
    }
    unless ($self->_cat_files($self->merged_alignments_file,@sub_alignment_files)){
        $self->error_message("Could not merge all alignment files");
        return;
    }
    unless ($self->_cat_files($self->merged_fasta_file,@fasta_files)){
        $self->error_message("Could not merge all alignment files");
        return;
    }

    $self->date_scheduled($start);
    $self->date_completed(UR::Time->now());
    $self->event_status('Succeeded');
    $self->event_type($self->command_name);
    $self->user_name($ENV{USER});

    return 1;
}


sub _cat_files {
    my $self = shift;
    my $out_file = shift;
    my @files = @_;

    if (-s $out_file) {
        $self->error_message("File already exists '$out_file'");
        return;
    }

    my $out_fh = IO::File->new($out_file,'w');
    unless ($out_fh) {
        $self->error_message("File will not open with write priveleges '$out_file'");
        return;
    }
    for my $in_file (@files) {
        my $in_fh = IO::File->new($in_file,'r');
        unless ($in_fh) {
            $self->error_message("File will not open with read priveleges '$in_file'");
            return;
        }
        while (my $line = $in_fh->getline()) {
            $out_fh->print($line);
        }
    }
    $out_fh->close();
    return 1;
}
1;

