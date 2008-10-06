package Genome::Model::Command::Build::ReferenceAlignment::UpdateGenotype::BreakPointRead454;

use strict;
use warnings;

use Genome;
use Command;
use Genome::Model;


class Genome::Model::Command::Build::ReferenceAlignment::UpdateGenotype::BreakPointRead454 {
    is => [
           'Genome::Model::Command::Build::ReferenceAlignment::UpdateGenotype',
       ],
    has => [
        ],
};

sub help_brief {
    my $self = shift;
    return "empty implementation of " . $self->command_name_brief;
}

sub help_synopsis {
    return <<"EOS"
    genome-model add-reads update-genotype-probabilities runMapping --model-id 5 --run-id 10
EOS
}

sub help_detail {
    return <<EOS
This command is usually called as part of the add-reads process
EOS
}

sub execute {
    my $self = shift;
    my $model = $self->model;
    my $break_point_path = 'perl ~jwalker/svn/perl_modules/breakPointRead/breakPointRead454.pl';

    my $merged_alignments_file = $self->parent_event->merged_alignments_file;
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
    return 1;
}

1;

