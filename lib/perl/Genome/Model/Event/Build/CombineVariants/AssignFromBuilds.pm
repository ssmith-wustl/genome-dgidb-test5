package Genome::Model::Event::Build::CombineVariants::AssignFromBuilds;

#:adukes short term leave as is, but if CombineVariants ever comes back, this needs to be updated to use Model inputs

class Genome::Model::Event::Build::CombineVariants::AssignFromBuilds {
    is => 'Genome::Model::Event',
};

sub execute {
    my $self = shift;
    my $model = $self->model;

    my $build = $self->build;

    my @from_models = $model->from_models;

    my @latest_builds = map {$_->last_complete_build} @from_models;

    unless (scalar @from_models == scalar @latest_builds){
        $self->error_message("Didn't get a build from each from models, crashing");
        die;
    }

    for (@latest_builds){
        $build->add_from_build(from_build => $_);
    }
}

1;
