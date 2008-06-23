package Genome::Model::Command::AddReads::FindVariations::BreakPointRead454;

use strict;
use warnings;

use above "Genome";
use Command;
use Genome::Model;

class Genome::Model::Command::AddReads::FindVariations::BreakPointRead454 {
    is => [
           'Genome::Model::Command::AddReads::FindVariations',
       ],
    has => [
            merged_alignments_file => {via => 'prior_event'},
            merged_fasta_file => {via => 'prior_event'},
            insertions_file => {
                                calculate_from => ['merged_alignments_file'],
                                calculate => q|
                                    return $merged_alignments_file .'.insertions';
                                |,
                            },
            deletions_file => {
                               calculate_from => ['merged_alignments_file'],
                               calculate => q|
                                    return $merged_alignments_file .'.deletions';
                                |,
                           },
            substitutions_file => {
                                   calculate_from => ['merged_alignments_file'],
                                   calculate => q|
                                    return $merged_alignments_file .'.substitutions';
                                |,
                               },
    ],

};

sub help_brief {
    my $self = shift;
    return "empty implementation of " . $self->command_name_brief;
}

sub help_synopsis {
    return <<"EOS"
    genome-model postprocess-alignments identify-variation break-point-read-454 --model-id 5 --ref-seq-id 10
EOS
}

sub help_detail {
    return <<EOS
This command is usually called as part of the postprocess-alignments process
EOS
}

sub execute {
    my $self = shift;
    my $model = $self->model;

    my $break_point_path = 'perl ~jwalker/svn/perl_modules/breakPointRead/breakPointRead454.pl';

    my $merged_alignments_file = $self->merged_alignments_file;
    unless ($merged_alignments_file && -s $merged_alignments_file) {
        $self->error_message("merged alignments file '$merged_alignments_file' does not exist or has zero size");
        return;
    }
    my $cmd = $break_point_path .' --blat-file '. $merged_alignments_file;
    $self->status_message('Running: '. $cmd);
    my $rv = system($cmd);
    unless ($rv == 0) {
        $self->error_message("non-zero exit code '$rv' from comamnd $cmd");
        return;
    }
    unless ($self->verify_successful_completion) {
        $self->error_message('Failed to verify successful completion of event '. $self->id .' on  ref seq '. $self->ref_seq_id);
        return;
    }
    return 1;
}

sub verify_successful_completion {
    my $self = shift;
    my @files_to_check = ($self->insertions_file, $self->deletions_file, $self->substitutions_file);
    for my $file (@files_to_check) {
        unless (-s $file) {
            $self->error_message("file '$file' does not exist or has zero size");
            return;
        }
    }
    return 1;
}


1;

