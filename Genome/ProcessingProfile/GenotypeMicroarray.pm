package Genome::ProcessingProfile::GenotypeMicroarray;

use Genome;

class Genome::ProcessingProfile::GenotypeMicroarray {
    is => 'Genome::ProcessingProfile',
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

1;

