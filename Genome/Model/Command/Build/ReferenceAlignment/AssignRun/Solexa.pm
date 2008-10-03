package Genome::Model::Command::Build::ReferenceAlignment::AssignRun::Solexa;

use strict;
use warnings;

use Genome;
use File::Path;
use GSC;

use IO::File;

class Genome::Model::Command::Build::ReferenceAlignment::AssignRun::Solexa {
    is => 'Genome::Model::Command::Build::ReferenceAlignment::AssignRun',
};

sub help_synopsis {
    return <<"EOS"
    genome-model add-reads assign-run solexa --model-id 5 --run-id 10
EOS
}

sub help_brief {
    "initializes the model for a solexa read set (single lane)"
}

sub help_detail {
    return <<EOS
This command is normally run automatically as part of "add-reads assign-run"
when it is determined that the run is from Solexa.
EOS
}

sub should_bsub { 0;}

sub create {
    my $class = shift;
    my $obj = $class->SUPER::create(@_);

    unless ($obj->model_id and $obj->read_set_id and $obj->event_type) {
        $class->error_message("This step requires the model and run to be specified at construction time for locking concurrency.");
        $obj->delete;
        return;
    }
    
    my $model = $obj->model;
    
    my $resource_id = join(".",$class,'create',$obj->read_set_id);
    my @prev =
        grep { $_ ne $obj }
        $class->load(
            model_id    => $obj->model_id,
            read_set_id => $obj->read_set_id,
            event_type  => $obj->event_type,
        );

    if (@prev) {
        $obj->error_message(
            "This run/lane, " 
            . $obj->run_name . "/" . $obj->run_subset_name. ' '
            . '(' . $obj->read_set_id . '),'
            . ' has already been assigned to this model '
            . $model->id . ' (' . $model->name . ')'
            . ' on event '
            . $prev[0]->genome_model_event_id
        );
        $obj->model->unlock_resource(resource_id => $resource_id);
        $obj->delete;
        return;
    }

    my $unlock = sub { $model->unlock_resource(resource_id => $resource_id) };
    $obj->create_subscription(method => 'commit', callback => $unlock);
    $obj->create_subscription(method => 'delete', callback => $unlock);

    return $obj;
}

sub execute {
    my $self = shift;
    $DB::single = $DB::stopper;
    unless (-d $self->build_directory) {
        $self->create_directory($self->build_directory);
    }
   return 1;
}

sub verify_successful_completion {
    my $self = shift;
    my $model = $self->model;
    unless (-d $self->build_directory) {
    	$self->error_message("Data parent directory doesnt exist: " . $self->build_directory);
        return 0;
    }
    return 1;
}



1;

