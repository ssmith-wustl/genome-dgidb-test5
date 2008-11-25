package Genome::Model::Command::Build::ReferenceAlignment::AssignRun::454;

use strict;
use warnings;

use Genome;
use Command;
use Genome::Model;
use File::Path;

class Genome::Model::Command::Build::ReferenceAlignment::AssignRun::454 {
    is => 'Genome::Model::Command::Build::ReferenceAlignment::AssignRun',
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

#TODO: Move to model 
sub amplicon_header_file {
    my $self = shift;
    #TODO: use read_set_link or instrument data?
    my $read_set = $self->read_set;
    return $read_set->full_path .'/amplicon_headers.txt';
}

sub execute {
    my $self = shift;
    $DB::single = $DB::stopper;
    my $model = $self->model;
    unless (-d $model->data_directory) {
        $self->create_directory($model->data_directory);
    }

    my $read_set = $self->read_set;
    unless (-d $read_set->full_path) {
        $self->create_directory($read_set->full_path);
    }
    if (-e $self->amplicon_header_file) {
        $self->error_message('Amplicon header file already exists: '. $self->amplicon_header_file);
        return;
    }
    my $fh = $self->create_file('amplicon_header_file',$self->amplicon_header_file);
    # Close the filehandle, delete and let the tool re-open filehandle
    $fh->close;
    unlink($self->amplicon_header_file);
    #TODO: use read_set_link or instrument data to get sample_name?
    my $amplicon = Genome::Model::Command::Report::Amplicons->create(
                                                                     sample_name => $read_set->sample_name,
                                                                     output_file => $self->amplicon_header_file,
                                                                 );
    unless ($amplicon) {
        $self->error_message('Failed to create amplicon report tool');
        return;
    }
    unless ($amplicon->execute) {
        $self->error_message('Failed to execute command '. $amplicon->command_name);
        return;
    }
    return 1;
}

sub verify_successful_completion {
    my $self = shift;
    my $model = $self->model;
    unless (-d $model->data_directory) {
    	$self->error_message('Data parent directory does not exist: '. $model->data_directory);
        return;
    }
    my $read_set = $self->read_set;
    unless (-d $read_set->full_path) {
        $self->error_message('Read Set data directory does not exist: '. $read_set->full_path);
        return;
    }
    return 1;
}

1;

