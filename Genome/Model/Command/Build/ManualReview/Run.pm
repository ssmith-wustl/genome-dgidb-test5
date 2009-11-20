package Genome::Model::Command::Build::ManualReview::Run;
#:adukes dump not used

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Build::ManualReview::Run {
    is => 'Genome::Model::Event',
 };

sub sub_command_sort_position { 40 }

sub help_brief {
    "Build for Manual Review models... not implemented yet"
}

sub help_synopsis {
    return <<"EOS"
genome-model build mymodel 
EOS
}

sub help_detail {
    return <<"EOS"
One build of a given ManualReview model.
EOS
}

sub execute {
    my $self = shift;

    # Some basic logic... may not need to be here depending on what you are doing I suppose, take it or leave it
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

    # TODO replace this with good logic
    $self->status_message("Build logic not implemented for Manual Review models yet... so this isnt really doing anything");
    return 1;
}


sub _get_sub_command_class_name{
  return __PACKAGE__; 
}

1;
