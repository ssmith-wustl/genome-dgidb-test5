# Review gsanders jlolofie
# The main think of here is adding some progrommatic way to pass every processing profile attribute to the workflow.
# Currently when a param is added to the workflow, I need to go add that as a class property to the processing profile,
# and then add it to this module to pass it to the workflow.
# Also should we check the workflow->execute return code at the end? I think we should. Lets talk to eclark about this.
# Note dkoboldt
# This RunWorkflow was copied from Genome/Model/Event/Build/Somatic/RunWorkFlow.pm to mimic and expand the somatic pipeline

package Genome::Model::Event::Build::SomaticCapture::RunWorkflow;

use strict;
use warnings;
use Genome;

class Genome::Model::Event::Build::SomaticCapture::RunWorkflow {
    is => ['Genome::Model::Event'],
};

sub help_brief {
    "Runs the somatic-capture pipeline on the latest build of the normal and tumor models for this somatic model"
}

sub help_synopsis {
    return <<"EOS"
genome model build mymodel
EOS
}

sub help_detail {
    return <<"EOS"
One build of a given SomaticCapture model.
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

    # Get the processing profile and the params we care about
    my $processing_profile = $model->processing_profile;
    unless ($processing_profile) {
        $self->error_message("Failed to get a processing_profile object!");
        return;
    }

    # Default to 0
    my $only_tier_1_flag = $processing_profile->only_tier_1;
    unless(defined $only_tier_1_flag) {
        $only_tier_1_flag = 0;
    }

    my $skip_sv_flag = $processing_profile->skip_sv;
    unless(defined $skip_sv_flag) {
        $skip_sv_flag = 0;
    }

    my $min_mapping_quality = $processing_profile->min_mapping_quality;
    my $min_somatic_quality = $processing_profile->min_somatic_quality;

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
    my $tumor_build = $tumor_model->last_succeeded_build;
    unless ($tumor_build) {
        $self->error_message("Failed to get a last_succeeded_build for the tumor model");
        return;
    }
    my $tumor_bam = $tumor_build->whole_rmdup_bam_file;
    unless (-e $tumor_bam) {
        $self->error_message("Tumor bam file $tumor_bam does not exist!");
        return;
    }

    # Get the bam files from the latest build directories from the normal model
    my $normal_build = $normal_model->last_succeeded_build;
    unless ($normal_build) {
        $self->error_message("Failed to get a last_succeeded_build for the normal model");
        return;
    }
    my $normal_bam = $normal_build->whole_rmdup_bam_file;
    unless (-e $normal_bam) {
        $self->error_message("Normal bam file $normal_bam does not exist!");
        return;
    }

    # Get the snp file from the tumor and normal models
    my $tumor_snp_file = $tumor_build->filtered_snp_file;
    unless (-e $tumor_snp_file) {
        $self->error_message("Tumor snp file $tumor_snp_file does not exist!");
        return;
    }
    my $normal_snp_file = $normal_build->filtered_snp_file;
    unless (-e $normal_snp_file) {
        $self->error_message("Normal snp file $normal_snp_file does not exist!");
        return;
    }
    
    my $workflow = Genome::Model::Tools::Somatic::Compare::CaptureBams->create(
        normal_bam_file => $normal_bam,
        tumor_bam_file => $tumor_bam,
        tumor_snp_file => $tumor_snp_file,
        normal_snp_file => $normal_snp_file,
        data_directory => $data_directory,
        only_tier_1 => $only_tier_1_flag,
        skip_sv => $skip_sv_flag,
        min_mapping_quality => $min_mapping_quality,
        min_somatic_quality => $min_somatic_quality,
        build_id => $build->id,
    );

    unless ($workflow) {
        $self->error_message("Failed to create workflow!");
        return;
    }

    $workflow->execute();

    return 1;
}

1;
