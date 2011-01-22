package Genome::ProcessingProfile::SomaticVariation;

use strict;
use warnings;

use Genome;

class Genome::ProcessingProfile::SomaticVariation{
    is => 'Genome::ProcessingProfile',
    has_param => [
        snv_detection_strategy => {
            doc => "Snv detector strategy string",
        },
        indel_detection_strategy => {
            doc => "Indel detector strategy string",
        },
        sv_detection_strategy => {
            doc => "SV detector strategy string",
        },
    ],
};

sub _initialize_build {
    my($self,$build) = @_;
    $DB::single=1;
    return 1;
}

sub _resolve_workflow_for_build {
    my $self = shift;
    $DB::single = 1;
    my $build = shift;

    my $operation = Workflow::Operation->create_from_xml(__FILE__ . '.xml');
    
    my $log_directory = $build->log_directory;
    $operation->log_dir($log_directory);
    
    #I think this ideally should be handled 
    $operation->name($build->workflow_name);

    return $operation;
}

sub _map_workflow_inputs {
    my $self = shift;
    $DB::single = 1;
    my $build = shift;

    my @inputs = ();

    # Verify the somatic model
    my $model = $build->model;
    
    unless ($model) {
        $self->error_message("Failed to get a model for this build!");
        die $self->error_message;
    }
    
    my $tumor_build = $build->tumor_build;
    my $normal_build = $build->normal_build;

    unless ($tumor_build) {
        $self->error_message("Failed to get a tumor_build associated with this somatic capture build!");
        die $self->error_message;
    }

    unless ($normal_build) {
        $self->error_message("Failed to get a normal_build associated with this somatic capture build!");
        die $self->error_message;
    }

    my $data_directory = $build->data_directory;
    unless ($data_directory) {
        $self->error_message("Failed to get a data_directory for this build!");
        die $self->error_message;
    }

    my $tumor_bam = $tumor_build->whole_rmdup_bam_file;
    unless (-e $tumor_bam) {
        $self->error_message("Tumor bam file $tumor_bam does not exist!");
        die $self->error_message;
    }

    my $normal_bam = $normal_build->whole_rmdup_bam_file;
    unless (-e $normal_bam) {
        $self->error_message("Normal bam file $normal_bam does not exist!");
        die $self->error_message;
    }

    # Get the snp file from the tumor and normal models
    my $tumor_snp_file = $tumor_build->filtered_snp_file;
    unless (-e $tumor_snp_file) {
        $self->error_message("Tumor snp file $tumor_snp_file does not exist!");
        die $self->error_message;
    }
    my $normal_snp_file = $normal_build->filtered_snp_file;
    unless (-e $normal_snp_file) {
        $self->error_message("Normal snp file $normal_snp_file does not exist!");
        die $self->error_message;
    }

    push @inputs, build_id => $build->id;

    return @inputs;
}

1;
