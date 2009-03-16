package Genome::Model::Command::Build::ImportedAnnotation::Run;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Build::ImportedAnnotation::Run {
    is => 'Genome::Model::Event',
 };

sub sub_command_sort_position { 41 }

sub help_brief {
    "Build for imported annotation  models (not implemented yet => no op)"
}

sub help_synopsis {
    return <<"EOS"
genome-model build mymodel 
EOS
}

sub help_detail {
    return <<"EOS"
One build of a given imported annotation database
EOS
}

sub execute {
    my $self = shift;
    my $model = $self->model;

    $self->status_message("Found Model: " . $model->name);

    $self->create_directory($self->build->data_directory);
    unless (-d $self->build->data_directory) {
        $self->error_message("Failed to create new build dir: " . $self->build->data_directory);
        die;
    }

    $self->status_message("Build logic not implemented for " . __PACKAGE__ . " models yet.  Implement me to download new annotation databases from NCBI or ensembl.");

    return 1;
}

1;
