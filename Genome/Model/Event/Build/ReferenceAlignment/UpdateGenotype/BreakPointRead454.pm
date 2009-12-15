package Genome::Model::Event::Build::ReferenceAlignment::UpdateGenotype::BreakPointRead454;

#REVIEW fdu
#1. Fix outdated help_brief/synopsis/detail
#2. Convert
#~jwalker/svn/perl_modules/breakPointRead/breakPointRead454.pl to
#genome model tool 

use strict;
use warnings;

use Genome;

class Genome::Model::Event::Build::ReferenceAlignment::UpdateGenotype::BreakPointRead454 {
    is => ['Genome::Model::Event::Build::ReferenceAlignment::UpdateGenotype'],
};

sub execute {
    my $self = shift;
    my $model = $self->model;
    my $break_point_path = 'perl ~jwalker/svn/perl_modules/breakPointRead/breakPointRead454.pl';

    my $merged_alignments_file = $self->build->merged_alignments_file;
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
