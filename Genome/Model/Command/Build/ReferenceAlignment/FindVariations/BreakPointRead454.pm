package Genome::Model::Command::Build::ReferenceAlignment::FindVariations::BreakPointRead454;

use strict;
use warnings;

use Genome;
use Command;
use Genome::Model;

class Genome::Model::Command::Build::ReferenceAlignment::FindVariations::BreakPointRead454 {
    is => [
           'Genome::Model::Command::Build::ReferenceAlignment::FindVariations',
       ],
    has => [
            merged_alignments_file => {via => 'prior_event'},
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

    my $insertions_cmd = $break_point_path .' --combine-indels '. $self->insertions_file;
    my $deletions_cmd = $break_point_path .' --combine-indels '. $self->deletions_file;
    my $substitutions_cmd = $break_point_path .' --combine-snps '. $self->substitutions_file;

    my @cmds = ($insertions_cmd,$deletions_cmd,$substitutions_cmd);
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

