package Genome::Model::Command::Build::Somatic::RunWorkflow;

use strict;
use warnings;
use Genome;

class Genome::Model::Command::Build::Somatic::RunWorkflow {
    is => ['Genome::Model::Event'],
};

sub help_brief {
    "Runs the somatic pipeline on the latest build of the normal and tumor models for this somatic model"
}

sub help_synopsis {
    return <<"EOS"
genome model build mymodel
EOS
}

sub help_detail {
    return <<"EOS"
One build of a given Somatic model.
EOS
}

sub execute {
    my $self = shift;
    $DB::single=1;

    # Verify the somatic model
    my $model = $self->model;
    unless ($model) {
        $self->error_message("Failed to get a model for this build!");
        return;
    }
    my $build = $self->build;
    unless ($build) {
        $self->error_message("Failed to get a build object!");
        return;
    }

    # Get the associated tumor and normal models
    my $tumor_model = $model->tumor_model;
    unless ($tumor_model) {
        $self->error_message("Failed to get a tumor_model associated with this somatic model!");
        return;
    }
    my $normal_model = $model->normal_model;
    unless ($normal_model) {
        $self->error_message("Failed to get a normal_model associated with this somatic model!");
        return;
    }

    my $data_directory = $self->build->data_directory;
    unless ($data_directory) {
        $self->error_message("Failed to get a data_directory for this build!");
        return;
    }

    # Get the bam files from the latest build directories from the tumor model
    my $tumor_build = $tumor_model->last_complete_build;
    unless ($tumor_build) {
        $self->error_message("Failed to get a last_complete_build for the tumor model");
        return;
    }
    my $tumor_bam = $tumor_build->whole_rmdup_bam_file;
    unless (-e $tumor_bam) {
        $self->error_message("Tumor bam file $tumor_bam does not exist!");
        return;
    }

    # Get the bam files from the latest build directories from the normal model
    my $normal_build = $normal_model->last_complete_build;
    unless ($normal_build) {
        $self->error_message("Failed to get a last_complete_build for the normal model");
        return;
    }
    my $normal_bam = $normal_build->whole_rmdup_bam_file;
    unless (-e $normal_bam) {
        $self->error_message("Normal bam file $normal_bam does not exist!");
        return;
    }

    # Get the snp file from the tumor model
    my $tumor_snp_file = $tumor_build->filtered_snp_file;
    unless (-e $tumor_snp_file) {
        $self->error_message("Tumor snp file $tumor_snp_file does not exist!");
        return;
    }
    
    my $workflow = Genome::Model::Tools::Somatic::Compare::Bams->create(
        normal_bam_file => $normal_bam,
        tumor_bam_file => $tumor_bam,
        tumor_snp_file => $tumor_snp_file,
        data_directory => $data_directory
    );

    unless ($workflow) {
        $self->error_message("Failed to create workflow!");
        return;
    }

    $workflow->execute();

    return 1;
}

1;
