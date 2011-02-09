package Genome::Model::Build::GenotypeMicroarray;

use strict;
use warnings;

use Genome;

class Genome::Model::Build::GenotypeMicroarray {
    is => 'Genome::Model::Build',
};

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_);
    return if not $self;

    # Gotta have a reference build
    my $reference_sequence_build = $self->model->reference_sequence_build;
    if ( not $reference_sequence_build ) {
        $self->error_message('No reference_sequence build for genotype model '.$self->model->__display_name__);
        $self->delete;
        return;
    }

    # Cannot handle multiple inst data, none is ok
    my @instrument_data = $self->instrument_data;
    if ( @instrument_data > 1 ) {
        $self->error_message('Cannot have more than one intrument data for a genotype microarray build '.$self->__display_name__);
        $self->delete;
        return;
    }

    # Do not allow a rebuild
    my @other_builds = grep { $self->id ne $_->id } $self->model->builds;
    if ( @other_builds ) {
        $self->error_message('Cannot rebuild genotype microarray model '.$self->model->__display_name__);
        $self->delete;
        return;
    }

    return $self;
}

sub formatted_genotype_file_path {
    shift->data_directory . '/formatted_genotype_file_path.genotype';
}

sub snvs_bed {
    shift->data_directory . '/gold_snp.v2.bed';
}

sub filtered_snvs_bed {
    shift->data_directory . '/gold_snp.v2.bed';
}

1;

