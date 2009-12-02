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

# Currently all processing profiles must implement the stages() method.
# This is sad.  We have a workflowless simple build which want to do less.
# I believe Eric Clark is fixing this.
sub stages {
    return ();
}

1;

