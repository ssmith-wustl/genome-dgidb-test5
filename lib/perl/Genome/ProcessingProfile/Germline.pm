package Genome::ProcessingProfile::Germline;

use strict;
use warnings;

use Genome;

class Genome::ProcessingProfile::Germline {
    is => 'Genome::ProcessingProfile',
    has => [
        server_dispatch => {
            is_constant => 1,
            is_class_wide => 1,
            value => 'long',
            doc => 'lsf queue to submit the launcher or \'inline\''
        },
        job_dispatch => {
            is_constant => 1,
            is_class_wide => 1,
            value => 'apipe',
            doc => 'lsf queue to submit jobs or \'inline\' to run them in the launcher'
        }
    ],
    has_param => [
        regions_file => 
        {
            type => 'String',
            is_optional => 0,
            doc => "Regions File that defines ROI",
        },
    ],
    doc => "Processing profile to run germline pipeline",
};

sub _execute_build {
    my ($self, $build) = @_;

    unless (-d $build->data_directory) {
        $self->error_message("Failed to find build directory: ".$build->data_directory);
        return;
    }
    else {
        $self->status_message("Created build directory: ".$build->data_directory);
    }
    my $regions_file = $self->regions_file;
    my $model = $build->model;
    my $model_subject = $model->subject;
    my $model_id = $model_subject->id;
    my $sample_name = $model_subject->subject->name;
    
    ## Establish sample output dir ##
    my $sample_output_dir = $build->data_directory;
    my $last_complete_build = $model_subject->last_complete_build;
    my $build_id = $last_complete_build->id;

    ## get the bam file ##
    my $bam_file = $last_complete_build->whole_rmdup_bam_file;
    my $snp_file = $last_complete_build->snp_file;
    my $indel_file = $last_complete_build->indel_file;

    if(-e $bam_file && -e $snp_file && -e $indel_file) {
        my $cmd_obj = Genome::Model::Tools::Germline::CaptureBams->create(
            build_id => $build_id,
            germline_bam_file => $bam_file,
            filtered_indelpe_snps => $snp_file,
            indels_all_sequences_filtered => $indel_file,
            data_directory => $sample_output_dir,
            regions_file => $regions_file,
        );					
        unless ($cmd_obj) {
            $self->error_message("Failed to create workflow!");
            return;
        }
        $cmd_obj->execute;
    }
    else {
        $self->error_message("Bam or SNP or Indel file undefined");
        return;
    }
    return 1;
}

1;

