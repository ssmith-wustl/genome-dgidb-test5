package Genome::Model::Event::Build::ReferenceAlignment::FindVariations::BreakPointRead;


#REVIEW fdu
#1. Fix wrong help_brief/synopsis/detail
#2. Convert bprStandalone to genome model tool


use strict;
use warnings;

use Genome;

class Genome::Model::Event::Build::ReferenceAlignment::FindVariations::BreakPointRead {
    is => ['Genome::Model::Event::Build::ReferenceAlignment::FindVariations'],
};

sub execute {
    my $self = shift;

    my $model = $self->model;

    my $cmd = 'bprStandalone --alignments-file '.  $self->build->merged_alignments_file
        .' --sample-name '. $model->subject_name .' --sff-file '. $self->build->merged_sff_file
            .' --output-dir '. $self->build->accumulated_alignments_directory
                .' --fasta-dir '. $self->build->merged_fasta_dir .' --qual-dir '. $self->build->merged_qual_dir;
    $self->status_message('Running: '. $cmd);
    my $rv = system($cmd);
    unless ($rv == 0) {
        $self->error_message("non-zero exit code '$rv' returned from '$cmd'");
        return;
    }
    return 1;
}


1;

