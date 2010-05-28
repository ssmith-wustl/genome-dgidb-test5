package Genome::Model::Tools::DetectVariants::Somatic;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::DetectVariants::Somatic {
    is => 'Genome::Model::Tools::DetectVariants',
    has => [
        control_aligned_reads_input => {
            is => 'Text',
            doc => 'Location of the control aligned reads file to which the input aligned reads file should be compared',
            shell_args_position => '2',
            is_input => 1,
            is_output => 1,
        },
    ]
};

1;
