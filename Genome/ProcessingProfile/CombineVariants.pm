package Genome::ProcessingProfile::CombineVariants;

use strict;
use warnings;

use Genome;

class Genome::ProcessingProfile::CombineVariants {
    is => 'Genome::ProcessingProfile::Staged',
    has_param => [
        limit_genes_to => {
            doc => 'What genes the analysis should be limited to. Comma delimited, leave blank for no limitation.',
            is_optional => 1,
        },
    ],
};

sub stages {
    return (qw/
             assign_from_builds
             combine_variants 
            /);
}

#TODO I think these are all obsolete due to the clustered assembly changes, most of these should be removed
#Genome::Model::Event::Build::CombineVariants::DeriveAssemblyNames
#Genome::Model::Event::Build::CombineVariants::DumpAssemblies
#Genome::Model::Event::Build::CombineVariants::VerifyAndFixAssembly
#Genome::Model::Event::Build::CombineVariants::RunDetectEvaluate
#Genome::Model::Event::Build::CombineVariants::ConfirmQueues
#Genome::Model::Event::Build::CombineVariants::BuildChildren
# 

sub combine_variants_job_classes {
    return (qw/
            Genome::Model::Event::Build::CombineVariants::CombineAndAnnotate
        /);
}

sub assign_from_builds_job_classes {
    return (qw/
        Genome::Model::Event::Build::CombineVariants::AssignFromBuilds
        /);
}


sub combine_variants_objects {
    return 1;
}

sub assign_from_builds_objects {
    return 1;
}

1;
