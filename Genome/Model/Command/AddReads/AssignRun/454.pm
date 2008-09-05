package Genome::Model::Command::AddReads::AssignRun::454;

use strict;
use warnings;

use above "Genome";
use Command;
use Genome::Model;
use File::Path;

class Genome::Model::Command::AddReads::AssignRun::454 {
    is => 'Genome::Model::Command::AddReads::AssignRun',
};

sub help_brief {
    "Creates the appropriate items on the filesystem for a new 454 run region"
}

sub help_synopsis {
    return <<"EOS"
    genome-model add-reads assign-run 454 --model-id 5 --read-set-id 10
EOS
}

sub help_detail {
    return <<EOS 
    This command is launched automatically by "add-reads assign-run"
    when it is determined that the run is from a 454.
EOS
}

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
    my $lock = $model->lock_resource(resource_id => $resource_id);
    unless ($lock) {
        $class->error_message("Failed to lock $resource_id.");
        $obj->delete;
        return;
    }

    my @prev =
        grep { $_ ne $obj }
        $class->load(
            model_id    => $obj->model_id,
            read_set_id      => $obj->read_set_id,
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
    my $model = $self->model;
    unless (-d $model->data_directory) {
        $self->create_directory($model->data_directory);
    }
    return 1;
}

sub verify_successful_completion {
    my $self = shift;
    my $model = $self->model;
    unless (-d $model->data_directory) {
    	$self->error_message("Data parent directory doesnt exist: ".$model->data_directory);
        return 0;
    }
    return 1;
}

1;

