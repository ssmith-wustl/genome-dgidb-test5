package Genome::Model::MutationalSignificance::Command::CalcCovg;

use strict;
use warnings;

use Genome;

class Genome::Model::MutationalSignificance::Command::CalcCovg {
    is => ['Command::V2'],
    has_input => [
        somatic_variation_build => {
            is => 'Genome::Model::Build::SomaticVariation',
        },
        output_dir => {
            is => 'Text',
            is_output => 1,
        },
        reference_sequence => {
            is => 'Text',
        },
        normal_min_depth => {
            is => 'Text',
            is_optional => 1,
        },
        tumor_min_depth => {
            is => 'Text',
            is_optional => 1,
        },
        min_mapq => {
            is => 'Text',
            is_optional => 1,
        },
        roi_file => {
            is => 'Text',
        },
    ],
    has_output => [
        output_file => {
            is => 'Text',
        },
    ],
};

sub execute {
    my $self = shift;

    $self->status_message("CalcCovg for build ".$self->somatic_variation_build->id);

    my $normal_bam = $self->somatic_variation_build->normal_bam;
    my $tumor_bam = $self->somatic_variation_build->tumor_bam;

    my $sample_name = $self->somatic_variation_build->tumor_build->model->subject->extraction_label;

    my $output_dir = $self->output_dir."/roi_covgs";

    unless (-d $output_dir) {
        Genome::Sys->create_directory($output_dir);
    }

    my $output_file = $output_dir."/".$sample_name.".covg";

    $self->output_file($output_file);

    my $cmd = Genome::Model::Tools::Music::Bmr::CalcCovgHelper->create (
        roi_file => $self->roi_file,
        reference_sequence => $self->reference_sequence,
        normal_bam => $normal_bam,
        tumor_bam => $tumor_bam,
        output_file => $output_file,
    );
    if ($self->normal_min_depth) {
        $cmd->normal_min_depth($self->normal_min_depth);
    }
    if ($self->tumor_min_depth) {
        $cmd->tumor_min_depth($self->tumor_min_depth);
    }
    if ($self->min_mapq) {
        $cmd->min_mapq($self->min_mapq);
    }
    $cmd->execute;

    my $status = "CalcCovg done";
    $self->status_message($status);
    return 1;
}

1;
