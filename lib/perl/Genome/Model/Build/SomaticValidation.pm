package Genome::Model::Build::SomaticValidation;

use strict;
use warnings;

use Genome;

class Genome::Model::Build::SomaticValidation {
    is => 'Genome::Model::Build',
    has_optional => [
        tumor_build_links => {
            is => 'Genome::Model::Build::Link', reverse_as => 'to_build', where => [ role => 'tumor'], is_many => 1,
            doc => 'The bridge table entry for the links to tumor builds (should only be one)',
        },
        tumor_build => {
            is => 'Genome::Model::Build', via => 'tumor_build_links', to => 'from_build',
            doc => 'The tumor build with which this build is associated',
        },
        normal_build_links => {
            is => 'Genome::Model::Build::Link', reverse_as => 'to_build', where => [ role => 'normal'], is_many => 1,
            doc => 'The bridge table entry for the links to normal builds (should only be one)',
        },
        normal_build => {
            is => 'Genome::Model::Build', via => 'normal_build_links', to => 'from_build',
            doc => 'The tumor build with which this build is associated'
        },
    ],
};

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);

    $DB::single = $DB::stopper;
    unless ($self) {
        return;
    }
    my $model = $self->model;
    unless ($model) {
        $self->error_message("Failed to get a model for this build!");
        return;
    }

    my $tumor_model = $model->tumor_model;
    unless ($tumor_model) {
        $self->error_message("Failed to get a tumor_model!");
        return;
    }

    my $normal_model = $model->normal_model;
    unless ($normal_model) {
        $self->error_message("Failed to get a normal_model!");
        return;
    }

    my $tumor_build = $tumor_model->last_complete_build;
    unless ($tumor_build) {
        $self->error_message("Failed to get a tumor build!");
        return;
    }

    my $normal_build = $normal_model->last_complete_build;
    unless ($normal_build) {
        $self->error_message("Failed to get a normal build!");
        return;
    }

    $self->add_from_build(role => 'tumor', from_build => $tumor_build);
    $self->add_from_build(role => 'normal', from_build => $normal_build);

    return $self;
}

sub workflow_name {
    my $self = shift;
    return $self->build_id . ' Somatic Variant Validation Pipeline';
}

sub calculate_estimated_kb_usage {
    my $self = shift;

    # FIXME find out how much we probably really need
    return 15_728_640;
}

sub files_ignored_by_diff {
    return qw(
        build.xml
    );
}

sub dirs_ignored_by_diff {
    return qw(
        logs/
        reports/
    );
}

1;
