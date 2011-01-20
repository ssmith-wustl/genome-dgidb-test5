package Genome::Model::Build::SomaticVariation;

use strict;
use warnings;

use Genome;

class Genome::Model::Build::SomaticVariation {
    is => 'Genome::Model::Build',
    has => [
        tumor_model => {
            is => 'Genome::Model::ReferenceAlignment',
            via => 'model',
        },
        normal_model => {
            is => 'Genome::Model::ReferenceAlignment',
            via => 'model',
        },
        annotation_build => {
            is => 'Genome::Model::Build::ImportedAnnotation',
            via => 'model',
        },
        previously_discovered_variations_build => {
            is => 'Genome::Model::Build::ImportedVariationList',
            via => 'model',
        },
    ],
};


sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);

    $DB::single=1;
    unless ($self) {
        return;
    }
   
    my $tumor_build = $self->tumor_model->last_complete_build;
    unless ($tumor_build) {
        $self->error_message("Failed to get a tumor build!");
        return;
    }

    my $normal_build = $self->normal_model->last_complete_build;
    unless ($normal_build) {
        $self->error_message("Failed to get a normal build!");
        return;
    }

    return $self;
}

sub calculate_estimated_kb_usage {
    my $self = shift;

    # 15 gig... overestimating by 50% or so...
    return 15728640;
}

sub files_ignored_by_diff {
    return qw(
    );
}

sub dirs_ignored_by_diff {
    return qw(
    );
}

1;
