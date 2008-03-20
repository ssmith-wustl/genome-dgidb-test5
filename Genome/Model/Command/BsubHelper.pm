package Genome::Model::Command::BsubHelper;

use strict;
use warnings;

use above "Genome";
use Command; 

class Genome::Model::Command::BsubHelper {
    is => 'Command',
    has => [
        event_id            => { is => 'Integer', doc => 'Identifies the Genome::Model::Event by id'},
        model_id            => { is => 'Integer', doc => "Identifies the genome model on which we're operating" },
        model               => { is => 'Genome::Model', id_by => 'model_id' },
    ],
    has_optional => [
        run_id              =>  { is => 'Integer'},
#        run                 =>  { is => 'Genome::RunChunk', id_by => 'run_id' },  # FIXME there's a bug where the initialization stuff appears to try to load this object even if run_id wasn't specified, causing it to not compile
        ref_seq_id          =>  { is => 'String'},
    ]
};

sub sub_command_sort_position { 100 }

sub help_brief {
    "Used by add-reads to run previously schedule Events on a blade"
}

sub help_synopsis {
    return <<"EOS"
genome-model bsub-helper --event-id 123456 --model_id 5 --run_id 1001
EOS
}

sub help_detail {
    return <<"EOS"
This command is run on a blade, and loads an already existing Event and executes it
EOS
}


sub execute {
    my $self = shift;

$DB::single=1;
    # Give the add-reads top level step a chance to sync database so these events
    # show up
    my $try_count = 10;
    my $event;
    while($try_count--) {
        $event = Genome::Model::Event->load(id => $self->event_id);
        last if ($event);
        sleep 5;
    }
    unless ($event) {
        $self->error_message('No event found with id '.$self->event_id);
        return;
    }

    unless ($event->model_id == $self->model_id) {
        $self->error_message("The model id for the loaded event ".$event->model_id.
                             " does not match the command line ".$self->model_id);
        return;
    }

    # Re-load the command object with the proper class.
    # FIXME Maybe Event.pm could be changed to do this for us at some point
    my $proper_command_class_name = $event->class_for_event_type();
    unless ($proper_command_class_name) {
        $self->error_message('Could not derive command class for command string '.$event->event_type);
        return;
    }

    my $command_obj = $proper_command_class_name->get(genome_model_event_id => $event->genome_model_event_id);

    $command_obj->lsf_job_id($ENV{'LSB_JOBID'});
    $command_obj->date_scheduled(UR::Time->now());
    $command_obj->event_status('Running');
    $command_obj->user_name($ENV{'USER'});

    #UR::Context->commit();

    my $rv = $command_obj->execute();

    $command_obj->date_completed(UR::Time->now());
    $command_obj->event_status($rv ? 'Succeeded' : 'Failed');

    return $rv;
}



1;

