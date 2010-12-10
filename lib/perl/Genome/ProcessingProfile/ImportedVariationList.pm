package Genome::ProcessingProfile::ImportedVariationList;

use strict;
use warnings;

use Genome;

class Genome::ProcessingProfile::ImportedVariationList {
    is => 'Genome::ProcessingProfile',
    has => [
        server_dispatch => {
            is_constant => 1,
            is_class_wide => 1,
            value => 'inline',
            doc => 'lsf queue to submit the launcher or \'inline\''
        },
        job_dispatch => {
            is_constant => 1,
            is_class_wide => 1,
            value => 'inline',
            doc => 'lsf queue to submit jobs or \'inline\' to run them in the launcher'
        }
    ],
    doc => "this processing profile does the file copying and indexing required to import variations"
};

sub _execute_build {
    my ($self, $build) = @_;
    unless($build->model) {
        $self->error_message("Couldn't find model for build id " . $build->build_id . ".");
        return;
    }
    $self->status_message("Done.");
    return 1;
}

sub _resolve_disk_group_name_for_build {
    return 'info_apipe_ref';
}


1;
