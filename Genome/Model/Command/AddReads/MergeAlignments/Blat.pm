package Genome::Model::Command::AddReads::MergeAlignments::Blat;

use strict;
use warnings;

use Genome;
use Command;
use Genome::Model;
use Genome::Utility::PSL::Writer;
use Genome::Utility::PSL::Reader;

class Genome::Model::Command::AddReads::MergeAlignments::Blat {
    is => [
           'Genome::Model::Command::AddReads::MergeAlignments',
       ],
    has => [
            merged_alignments_file => {
                                      calculate_from => ['model'],
                                      calculate => q|
                                          return $model->accumulated_alignments_directory .'/'. $model->sample_name .'.psl';
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

    $DB::single = $DB::stopper;

    my $start = UR::Time->now;
    my $model = $self->model;

    my $alignments_dir = $model->accumulated_alignments_directory;
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

    my @alignment_events = $model->alignment_events;
    unless (scalar(@alignment_events)) {
        $self->error_message('No alignment events found for model '. $model->id );
        return;
    }
    my @alignment_files;
    for my $alignment_event (@alignment_events) {
        my $alignment_file = $alignment_event->alignment_file;
        unless ($alignment_file) {
            $self->error_message('Failed to find alignment_file for event '. $alignment_event->id);
            return;
        }
        push @alignment_files, $alignment_file;
    }
    unless ($self->_cat_psl($self->merged_alignments_file,@alignment_files)){
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


sub _cat_psl {
    my $self = shift;
    my $out_file = shift;
    my @files = @_;

    if (-s $out_file) {
        $self->error_message("File already exists '$out_file'");
        return;
    }
    my $writer = Genome::Utility::PSL::Writer->create(
                                                   file => $out_file,
                                               );
    unless ($writer) {
        $self->error_message("Could not create a writer for file '$out_file'");
        return;
    }
    for my $in_file (@files) {
        my $reader = Genome::Utility::PSL::Reader->create(
                                                          file => $in_file,
                                                          );
        unless ($reader) {
            $self->error_message("Could not create a reader for file '$in_file'");
            return;
        }
        while (my $record = $reader->next) {
            $writer->write_record($record);
        }
        $reader->close;
    }
    $writer->close();
    return 1;
}
1;

