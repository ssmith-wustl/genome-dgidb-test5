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
        regions_file => {
            type => 'String',
            doc => "Regions File that defines ROI",
        },
    ],
    doc => "Processing profile to run germline pipeline",
};

sub _execute_build {
    my ($self, $build) = @_;

    unless (-d $build->data_directory) {
        $self->error_message("Failed to find build directory: " . $build->data_directory);
        return;
    }
    else {
        $self->status_message("Created build directory: " . $build->data_directory);
    }

    my $source_build = $build->source_build;
    my $bam_file = $source_build->whole_rmdup_bam_file;
    my $snp_file = $source_build->snv_file;
    my $indel_file = $source_build->indel_file;

    if(-e $bam_file && -e $snp_file && -e $indel_file) {
        my $cmd_obj = Genome::Model::Tools::Germline::CaptureBams->create(
            build_id => $source_build->id,
            germline_bam_file => $bam_file,
            filtered_indelpe_snps => $snp_file,
            indels_all_sequences_filtered => $indel_file,
            data_directory => $build->data_directory,
            regions_file => $self->regions_file,
        );					
        unless ($cmd_obj) {
            $self->error_message("Failed to create workflow!");
            return;
        }
        $cmd_obj->execute;
    }
    else {
        $self->error_message("Bam file $bam_file does not exist!") unless -e $bam_file;
        $self->error_message("Snp file $snp_file does not exist!") unless -e $snp_file;
        $self->error_message("Indel file $indel_file does not exist!") unless -e $indel_file;
        return;
    }
    return 1;
}

1;

