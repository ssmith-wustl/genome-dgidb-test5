package Genome::Model::Command::AddReads::MergeAlignments::BlatPlusCrossmatch;

use strict;
use warnings;

use above "Genome";
use Command;
use Genome::Model;
use IO::File;


class Genome::Model::Command::AddReads::MergeAlignments::BlatPlusCrossmatch {
    is => [
           'Genome::Model::Command::AddReads::MergeAlignments',
       ],
    has => [
            merged_alignments_file => {
                                      calculate_from => ['model','ref_seq_id'],
                                      calculate => q|
                                          return $model->alignments_directory .'/'. $ref_seq_id .'.psl';
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
    #my @succeeded_events =
    #    grep { my $m = $_->metrics(name => 'read set pass fail'); (!$m or $m->value eq 'pass') }
    #        Genome::Model::Command::AddReads::AcceptReads::BlatPlusCrossmatch->get(
    #                                                                               model_id => $model->id,
    #                                                                               event_status => 'Succeeded'
    #                                                                           );

    my @succeeded_events = $model->alignment_events;
    my @sub_alignment_files;
    for my $event (@succeeded_events) {
        #my $align_reads = Genome::Model::Command::AddReads::AlignReads::BlatPlusCrossmatch->get(
        #                                                                                        model_id   => $model->id,
        #                                                                                        read_set_id     => $event->read_set_id,
        #                                                                                    );
        push @sub_alignment_files, $event->blat_output;
    }
    unless ($self->_cat_files($self->merged_alignments_file,@sub_alignment_files)){
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

    for my $file (@files) {
        my $rv = system sprintf('cat %s >> %s', $file, $out_file);
        unless ($rv == 0) {
            $self->error_message("Failed to cat '$file' onto '$out_file'");
            return;
        }
    }
    return 1;
}
1;

