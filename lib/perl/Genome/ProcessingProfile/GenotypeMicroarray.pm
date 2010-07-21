package Genome::ProcessingProfile::GenotypeMicroarray;

use Genome;

class Genome::ProcessingProfile::GenotypeMicroarray {
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
    has_param => [
        input_format => {
            doc => 'file format, defaults to "wugc", which is currently the only format supported',
            valid_values => ['wugc'],
            default_value => 'wugc',
        },
        instrument_type => {
            doc => 'the type of microarray instrument',
            valid_values => ['illumina','affymetrix','unknown'],
        },
    ],
};

sub _execute_build {
    my $self = shift;
    $self->status_message("Logging SNP array data...\n");
    return 1;
}

sub classes_for_stage {
    return ();
}
sub objects_for_stage {
    return ();
}

sub stages {
    return (qw/
            GenotypeMicroarray
            /);
}

sub genotype_microarray_job_classes {
    return (qw/
            Genome::Model::Event::Build::GenotypeMicroarray::NoOp
        /);
}

sub genotype_microarray_objects {
    return 1;
}


1;

