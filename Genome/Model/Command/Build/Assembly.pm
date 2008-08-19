package Genome::Model::Command::Build::Assembly;

use strict;
use warnings;

use above "Genome";

class Genome::Model::Command::Build::Assembly {
    is => 'Genome::Model::Command::Build',
    has => [
        ],
 };

sub sub_command_sort_position { 40 }

sub command_subclassing_model_property {
    print "hi\n";
    'foora'
}

sub help_brief {
    "assemble a genome"
}

sub help_synopsis {
    return <<"EOS"
genome-model build mymodel 
EOS
}

sub help_detail {
    return <<"EOS"
One build of a given assembly model.
EOS
}

sub subordinate_job_classes {
    return (
            'Genome::Model::Command::Build::Assembly::AssignReadSetToModel',
            'Genome::Model::Command::Build::Assembly::FilterReadSet',
            'Genome::Model::Command::Build::Assembly::TrimReadSet',
            'Genome::Model::Command::Build::Assembly::AddReadSetToProject',
    );
}

sub execute {
    my $self = shift;

    $DB::single = $DB::stopper;
    my $model = $self->model;
    
    my @sub_command_classes = $self->subordinate_job_classes;
    my $last_event_id;
    my @available_read_sets = $model->available_read_sets;
    for my $read_set (@available_read_sets) {
        my $prior_event_id = undef;
        foreach my $command_class ( @sub_command_classes ) {
            my $command = $command_class->create(
                                                 model_id => $self->model_id,
                                                 #should be read_set_id but still uses old name
                                                 run_id => $read_set->id,
                                                 prior_event_id => $prior_event_id,
                                                 parent_event_id => $self->id,
                                             );
            $command->parent_event_id($self->id);
            $command->event_status('Scheduled');
            $command->retry_count(0);
            $prior_event_id = $command->id;
        }
        $last_event_id = $prior_event_id;
    }

    my $data_directory = $model->data_directory;
    unless (-e $data_directory) {
        unless($self->create_directory($data_directory)) {
            $self->error_message("Failed to create directory '$data_directory'");
            return;
        }
    }
    my $assembler = Genome::Model::Command::Build::Assembly::Assemble->create(
                                                                              model_id => $self->model_id,
                                                                              prior_event_id => $last_event_id,
                                                                              parent_event_id => $self->id,
                                                                          );
    $assembler->parent_event_id($self->id);
    $assembler->event_status('Scheduled');
    $assembler->retry_count(0);
    $last_event_id= $assembler->id;

    return 1;
}


sub _get_sub_command_class_name{
  return __PACKAGE__; 
}

1;

