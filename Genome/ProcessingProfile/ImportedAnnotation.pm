package Genome::ProcessingProfile::ImportedAnnotation;

use strict;
use warnings;

use Genome;

class Genome::ProcessingProfile::ImportedAnnotation{
    is => 'Genome::ProcessingProfile::Staged',
    has_param => [
        annotation_source => {
            is_optional => 0,
            doc => 'Where the annotation comes from (ensembl, genbank, etc.) This value is "combined-annotation" for a combined-annotation model',
        }
    ],
    
};

sub stages {
    return (qw/
              imported_annotation
            /);
}

sub imported_annotation_job_classes {
    return (qw/
        Genome::Model::Event::Build::ImportedAnnotation::Run
        /);
}

sub imported_annotation_objects {
    return 1;
}
1;
