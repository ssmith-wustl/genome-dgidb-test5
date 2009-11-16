package Genome::ProcessingProfile::ImportedAnnotation;

#:eclark 11/16/2009 Code review.

# Short term: There should be a better way to define the class than %HAS.
# Long term: See Genome::ProcessingProfile notes.

use strict;
use warnings;

use Genome;

class Genome::ProcessingProfile::ImportedAnnotation{
    is => 'Genome::ProcessingProfile',
    has => [
        annotation_source => {
            doc => 'Where the annotation comes from (ensembl, genbank, etc.) This value is "combined-annotation" for a combined-annotation model',
            is_optional => 0,
            is_mutable => 1,
            via => 'params',
            to => 'value',
            where => [name => 'annotation_source'],
        }
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
