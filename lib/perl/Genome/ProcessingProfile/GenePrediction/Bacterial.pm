package Genome::ProcessingProfile::GenePrediction::Bacterial;

use strict;
use warnings;

use Genome;
use Carp 'confess';

class Genome::ProcessingProfile::GenePrediction::Bacterial {
    is => 'Genome::ProcessingProfile::GenePrediction',
    has_param => [
        skip_core_gene_check => {
            is => 'Boolean',
            doc => 'If set, the core gene check is not performed',
            is_optional => 1,
            default => 0,
        },
        minimum_sequence_length => {
            is => 'Number',
            doc => 'Minimum contig sequence length',
            is_optional => 1,
            default => 200,
        },
        runner_count => {
            is => 'Number',
            doc => 'Number of runners for the gene prediction step',
            is_optional => 1,
            default => 50,
        }, 
        skip_acedb_parse => {
            is => 'Boolean',
            doc => 'If set, skip aceDB parsing in bap project finish',
            is_optional => 1,

        },
    ],
    doc => "Processing profile for gene prediction and merging models"
};

sub _resolve_type_name_for_class {
    return "gene prediction";
}

sub _execute_build {
    my ($self, $build) = @_;

    # I want my status messages, dammit!
    $ENV{UR_COMMAND_DUMP_STATUS_MESSAGES} = 1;

    my $model = $build->model;
    $self->status_message("Executing build logic for " . $self->__display_name__ . ":" . $build->__display_name__);

    # TODO Make explicit build links between this build and the assembly build for tracking

    my $config_file_path = $build->create_config_file;
    unless (-s $config_file_path) {
        $self->error_message("Configuration file not found at expected location: $config_file_path");
        confess;
    }

    $self->status_message("Configuration file created at $config_file_path, creating hap command object");

    my $hap_object = Genome::Model::Tools::Hgmi::Hap->create(
        config => $config_file_path,
        dev => $model->dev,
        skip_core_check => $self->skip_core_gene_check,
        skip_protein_annotation => 1, # TODO Eventually, this build process will include PAP and BER
    );
    unless ($hap_object) {
        $self->error_message("Could not create hap command object!");
        confess;
    }

    $self->status_message("Hap command object created, executing!");

    # THIS IS IMPORTANT! Hap creates forked processes as part of the prediction step, and these child
    # processes get a REFERENCE to open db handles, which get cleaned up and closed during cleanup of
    # the child process. This causes problems in this process, because it expects the handle to still be
    # open. Attempting to use that handle results in frustrating errors like this:
    # DBD::Oracle::db rollback failed: ORA-03113: end-of-file on communication channel (DBD ERROR: OCITransRollback)
    if (Genome::DataSource::GMSchema->has_default_handle) {
        $self->status_message("Disconnecting GMSchema default handle.");
        Genome::DataSource::GMSchema->disconnect_default_dbh();
    }

    my $hap_rv = $hap_object->execute;
    unless ($hap_rv) {
        $self->error_message("Trouble executing hap command!");
        confess;
    }

    $self->status_message("Hap executed and no problems detected!");
    return 1;
}

1;


