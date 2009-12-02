package Genome::ProcessingProfile::GenotypeMicroarray;

#:eclark 11/16/2009 Code review.

# Short term: There should be a better way to define the class than %HAS.
# Long term: See Genome::ProcessingProfile notes.

use Genome;

# TODO: nearly all of this is boilerplate copied from ReferenceAlignment.
# Pull the guts into the base class and improve the infrastructure so making new models types is easy.

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

