package Genome::ProcessingProfile::ImportedAnnotation;

use strict;
use warnings;

use Genome;

class Genome::ProcessingProfile::ImportedAnnotation{
    is => 'Genome::ProcessingProfile',
    has => [
        reference_sequence_model_id => {
            doc => 'What genes the analysis should be limited to. Comma delimited, leave blank for no limitation.',
            is_optional => 0,
            is_mutable  => 1,
            via         => 'params',
            to          => 'value',
            where       => [name => 'reference_sequence_model_id'],
        },
    ],
    
};

sub stages {
    return (qw/
              imported_annotation
              verify_successful_completion
            /);
}

sub imported_annotation_job_classes {
    return (qw/
        Genome::Model::Command::Build::ImportedAnnotation::Run
        /);
}


sub imported_annotation_objects {
    return 1;
}
1;
