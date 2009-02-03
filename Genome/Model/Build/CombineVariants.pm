package Genome::Model::Build::CombineVariants;

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
