package Genome::Model::SomaticValidation::Command::DetectVariants;

use strict;
use warnings;

use Genome;

class Genome::Model::SomaticValidation::Command::DetectVariants{
    is => 'Genome::Model::SomaticVariation::Command::DetectVariants',
    has =>[
        build_id => {
            is => 'Integer',
            is_input => 1,
            is_output => 1,
            doc => 'build id of SomaticValidation model',
        },
        build => {
            is => 'Genome::Model::Build::SomaticValidation',
            id_by => 'build_id',
        },
    ],
    #specific things used by the final process-validation script
    has_output_optional => [
        hq_snv_file => {
            is => 'Text',
            doc => 'The filtered snv file from the DV run',
        },
        lq_snv_file => {
            is => 'Text',
            doc => 'The unfiltered snv file from the DV run',
        }
    ],
};

sub execute {
    my $self = shift;

    unless($self->SUPER::_execute_body()) {
        die $self->error_message();
    }

    #find the relevant output files
    my $version = 2; #TODO version support
    my $hq_snv_file = $self->build->data_set_path('variants/snvs.hq', $version, 'bed');
    my $lq_snv_file = $self->build->data_set_path('variants/snvs.lq', $version, 'bed');

    unless($hq_snv_file) {
        die $self->error_message('Could not find an HQ snv file.');
    }
    unless($lq_snv_file) {
        die $self->error_message('Could not find an LQ snv file.');
    }

    $self->hq_snv_file($hq_snv_file);
    $self->lq_snv_file($lq_snv_file);

    return 1;
}


1;
