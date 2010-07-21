package Genome::ProcessingProfile::ImportedVariations;

use strict;
use warnings;

use File::Copy;
use File::Path qw/make_path/;
use File::Spec;
use Genome;


#TODO   This module is being checked in now so that when a processing profile is defined for 
#       ImportedVariations, things won't blow up too bad. This is a placeholder.   rlong




my $num4GiB = 4294967296;

class Genome::ProcessingProfile::ImportedVariations {
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

    my $model = $build->model;

    if(!$model)
    {
        $self->error_message("Couldn't find model for build id " . $build->build_id . ".");
        return;
    }

    #my $variationSize = -s $build->variation_file;
    #unless(-e $build->variation_file && $variationSize > 0)
    #{
    #    $self->status_message("Imported Variation file \"" . $build->variation_file . "\" is either inaccessible, empty, or non-existent.");
    #    return;
    #}

    $self->status_message("Done.");
    return 1;
}

sub _resolve_disk_group_name_for_build {
    return 'info_apipe_ref';
}



1;
