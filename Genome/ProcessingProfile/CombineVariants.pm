package Genome::ProcessingProfile::CombineVariants;

use strict;
use warnings;

use Genome;

class Genome::ProcessingProfile::CombineVariants {
    is => 'Genome::ProcessingProfile::Composite',
    has => [
        limit_genes_to => {
            doc => 'What genes the analysis should be limited to. Comma delimited, leave blank for no limitation.',
            is_optional => 1,
            is_mutable  => 1,
            via         => 'params',
            to          => 'value',
            where       => [name => 'limit_genes_to'],
        },
    ],
};

sub params_for_class{
    my $self = shift;
    return qw/limit_genes_to/;
}

sub stages {
    return (qw/
             combine_variants
             verify_successful_completion
            /);
}

#Genome::Model::Command::Build::CombineVariants::DeriveAssemblyNames
#Genome::Model::Command::Build::CombineVariants::DumpAssemblies
#Genome::Model::Command::Build::CombineVariants::VerifyAndFixAssembly
#Genome::Model::Command::Build::CombineVariants::RunDetectEvaluate
#Genome::Model::Command::Build::CombineVariants::ConfirmQueues
#Genome::Model::Command::Build::CombineVariants::BuildChildren
# 
sub combine_variants_job_classes {
    return (qw/
            Genome::Model::Command::Build::CombineVariants::CombineAndAnnotate
        /);
}

sub combine_variants_objects {
    return 1;
}

1;
