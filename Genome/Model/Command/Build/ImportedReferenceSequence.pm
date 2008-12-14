package Genome::Model::Command::Build::ImportedReferenceSequence;

use strict;
use warnings;
use Genome;

class Genome::Model::Command::Build::ImportedReferenceSequence {
    is => 'Genome::Model::Command::Build',
 };

sub sub_command_sort_position { 40 }

sub help_brief {
    "Build for imported reference sequence models (not implemented yet => no op)"
}

sub help_synopsis {
    return <<"EOS"
genome-model build mymodel 
EOS
}

sub help_detail {
    return <<"EOS"
One build of a given imported reference sequence
EOS
}

sub execute {
    my $self = shift;
    my $model = $self->model;

    $self->status_message("Found Model: " . $model->name);
    
    $self->create_directory($self->data_directory);
    unless (-d $self->data_directory) {
        $self->error_message("Failed to create new build dir: " . $self->data_directory);
        die;
    }

    $self->status_message("Build logic not implemented for " . __PACKAGE__ . " models yet.  Implement me to downoad new references from NCBI, and link to LIMS references.");
    return 1;
    
    return $model;
}


sub _get_sub_command_class_name{
  return __PACKAGE__; 
}

1;
