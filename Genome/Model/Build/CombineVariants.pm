package Genome::Model::Build::CombineVariants;
#:adukes short-term remove composite model references, long-term this was part of a messy project, reevaluate what is being accomplished here and decide if we still want to support it.

use strict;
use warnings;

use Genome;

class Genome::Model::Build::CombineVariants {
    is => 'Genome::Model::Build',
};

sub assemblies_to_run_file {
    my $self = shift;

    my $build_dir = $self->data_directory;
    return "$build_dir/assemblies_to_run.txt";
}

sub assembly_directory {
    my $self = shift;

    return "/gscmnt/sata810/info/medseq/Genome_model_combine_variants_assemblies/";
}

1;
