package Genome::Model::Event::Build::CombineVariants::CombineAndAnnotate;

#:adukes Like the rest of the modules under G:M:C:Build, should be moved to its appropriate G:M:Build namespace

class Genome::Model::Event::Build::CombineVariants::CombineAndAnnotate {
    is => 'Genome::Model::Event',
};

sub execute {
    my $self = shift;
    my $model = $self->model;
    unless ($model){
        $self->error_message("Couldn't find model for id ".$self->model_id);
        die;
    }
    $self->status_message("Found Model: " . $model->name);

    $self->create_directory($self->build->data_directory);
    unless (-d $self->build->data_directory) {
        $self->error_message("Failed to create new build dir: " . $self->build->data_directory);
        die;
    }

    $self->status_message("Combining variants");
    $model->combine_variants();

    $self->status_message("Annotating variants");
    $model->annotate_variants();

    $self->status_message("Writing maf files");
    $model->write_post_annotation_maf_files();

    return $model;
}

1;
