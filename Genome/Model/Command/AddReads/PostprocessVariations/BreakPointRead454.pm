package Genome::Model::Command::AddReads::PostprocessVariations::BreakPointRead454;

use strict;
use warnings;

use above "Genome";
use Command;
use Genome::Model;

class Genome::Model::Command::AddReads::PostprocessVariations::BreakPointRead454 {
    is => [
           'Genome::Model::Command::AddReads::PostprocessVariations',
       ],
    has => [
            merged_alignments_file => { via => 'prior_event' },
            merged_fasta_file => {via => 'prior_event'},
            insertions_file => { via => 'prior_event' },
            combined_insertions_file => {
                                         calculate_from => ['insertions_file'],
                                         calculate => q|
                                             return $insertions_file .'.combined';
                                         |,
                                     },
            deletions_file => { via => 'prior_event' },
            combined_deletions_file => {
                                         calculate_from => ['deletions_file'],
                                         calculate => q|
                                             return $deletions_file .'.combined';
                                         |,
                                     },
            substitutions_file => { via => 'prior_event' },
            combined_substitutions_file => {
                                         calculate_from => ['substitutions_file'],
                                         calculate => q|
                                             return $substitutions_file .'.combined';
                                         |, 
                                     },
            coverage_blocks_file => {
                                     calculate_from => ['merged_alignments_file'],
                                     calculate => q|
                                         return $merged_alignments_file .'.coverage.blocks';
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

    my @sibling_events = $self->sibling_events;
    my @merged_alignments_events = grep { $_->event_type =~ /merge-alignments/
                                             && $_->ref_seq_id eq $self->ref_seq_id } @sibling_events;
    if (scalar(@merged_alignments_events) > 1) {
        $self->error_message("Not setup to handle multiple ref seqs yet");
        return;
    }
    my $merged_alignments_event = $merged_alignments_events[0];
    if (!$merged_alignments_event) {
        $self->error_message("No merge alignment found");
        return;
    }
    my $merged_alignments_file = $merged_alignments_event->merged_alignments_file;
    unless ($merged_alignments_file && -s $merged_alignments_file) {
        $self->error_message("merged alignments file '$merged_alignments_file' does not exist or has zero size");
        return;
    }

    my $insertions_cmd = $break_point_path .' --combine-indels '. $self->insertions_file;
    my $deletions_cmd = $break_point_path .' --combine-indels '. $self->deletions_file;
    my $substitutions_cmd = $break_point_path .' --combine-snps '. $self->substitutions_file;
    my $snp_cmd = sprintf("%s --genotype-snps %s --alignment-file %s --sample-name %s",
                          $break_point_path,
                          $self->combined_substitutions_file,
                          $self->coverage_blocks_file,
                          $model->sample_name);
    my $in_cmd = sprintf("%s --genotype-indels %s --alignment-file %s --sample-name %s --reads-fasta %s --ref-dir %s",
                            $break_point_path,
                            $self->combined_insertions_file,
                            $self->coverage_blocks_file,
                            $model->sample_name,
                            $model->alignments_directory,
                            $model->reference_sequence_path,
                        );
    my $del_cmd = sprintf("%s --genotype-indels %s --alignment-file %s --sample-name %s --reads-fasta %s --ref-dir %s",
                            $break_point_path,
                            $self->combined_deletions_file,
                            $self->coverage_blocks_file,
                            $model->sample_name,
                            $model->alignments_directory,
                            $model->reference_sequence_path,
                        );

    my @cmds = ($insertions_cmd,$deletions_cmd,$substitutions_cmd,$snp_cmd,$in_cmd,$del_cmd);
    for my $cmd (@cmds) {
        $self->status_message('Running: '. $cmd);
        my $rv = system($cmd);
        unless ($rv == 0) {
            $self->error_message("non-zero exit code '$rv' returned from '$cmd'");
            return;
        }
    }
    return 1;
}



1;

