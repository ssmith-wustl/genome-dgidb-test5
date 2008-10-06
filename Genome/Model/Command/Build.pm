package Genome::Model::Command::Build;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Build {
    is => ['Genome::Model::Event'],
    type_name => 'genome model build',
    table_name => 'GENOME_MODEL_BUILD',
    first_sub_classification_method_name => '_resolve_subclass_name',
    id_by => [
        build_id                 => { is => 'NUMBER', len => 10, constraint_name => 'GMB_GME_FK' , is_optional => 1},
    ],
    has => [
        model                    => { is => 'Genome::Model', id_by => 'model_id', constraint_name => 'GMB_GMM_FK' },
        data_directory           => { is => 'VARCHAR2', len => 1000, is_optional => 1 },
        auto_execute => {
                         is => 'Boolean',
                         doc => 'The build will execute genome-model run-jobs before completing',
                         default_value => 1,
                         is_transient => 1,
                     },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
};

sub stages {
    my $class = shift;
    $class = ref($class) if ref($class);
    die("Please implement stages in class '$class'");
}

sub command_subclassing_model_property {
    return 'build_subclass_name';
}

sub resolve_data_directory {
    my $self = shift;
    my $model = $self->model;
    return $model->data_directory . '/build' . $self->id;
}

sub build_in_stages {
    my $self = shift;

    $self->data_directory($self->resolve_data_directory);
    my @stages = $self->stages;
    for my $stage_name (@stages) {
        my @stage_classes = $self->classes_for_stage($stage_name);
        $self->_verify_existing_events(\@stage_classes);

        my @objects = $self->objects_for_stage($stage_name);
        my @scheduled_objects = $self->_schedule_stage(\@stage_classes,\@objects);
        if ($self->auto_execute) {
            my $return_value = $self->_run_stage(@scheduled_objects);
            if ($return_value == 1) {
                $self->event_status('Succeeded');
                $self->date_completed(UR::Time->now);
                return $return_value;
            }
        }
    }
    return 1;
}

sub classes_for_stage {
    my $self = shift;
    my $stage_name = shift;
    my $classes_method_name = $stage_name .'_job_classes';
    return $self->$classes_method_name;
}

sub objects_for_stage {
    my $self = shift;
    my $stage_name = shift;
    my $objects_method_name = $stage_name .'_objects';
    return $self->$objects_method_name;
}

sub _verify_existing_events {
    my $self = shift;
    my $command_classes_ref = shift;

    my $model = $self->model;
    for my $command_class (@$command_classes_ref) {
        if (ref($command_class) eq 'ARRAY') {
            $self->_verify_existing_events($command_class);
        } else {
            my @events = $command_class->get( model_id => $model->id );
            my @broke_events = grep {$_->event_status =~ /Scheduled|Running|Crashed|Failed/} @events;
            if( @broke_events ) {
                my $error_message = 'Found '. scalar(@broke_events) .' broken events for class '. $command_class ."\n";
                for (@broke_events) {
                    $error_message .= $_->id ."\t". $_->event_type ."\t". $_->event_status ."\n";
                }
                $self->cry_for_help($error_message);
                die($error_message);
            }
        }
    }
    return 1;
}

sub _schedule_stage {
    my $self = shift;
    my $sub_command_classes_ref = shift;
    my $objects_to_schedule = shift;

    my @scheduled_commands;
    foreach my $object (@$objects_to_schedule) {
        my $object_class;
        my $object_id;
        if (ref($object)) {
            $object_class = ref($object);
            $object_id = $object->id;
        } else {
            $object_class = 'reference_sequence';
            $object_id = $object;
        }
        $self->status_message('Scheduling for '. $object_class);
        push @scheduled_commands, $self->_schedule_command_classes_for_object($object,$sub_command_classes_ref);
    }
    return @scheduled_commands;
}

sub _schedule_command_classes_for_object {
    my $self = shift;
    my $object = shift;
    my $command_classes = shift;
    my $prior_event_id = shift;

    $DB::single = 1;
    my @scheduled_commands;
    for my $command_class (@{$command_classes}) {
        if (ref($command_class) eq 'ARRAY') {
            push @scheduled_commands, $self->_schedule_command_classes_for_object($object,$command_class,$prior_event_id);
        } else {
            if ($command_class->can('command_subclassing_model_property')) {
                my $subclassing_model_property = $command_class->command_subclassing_model_property;
                unless ($self->model->$subclassing_model_property) {
                    $self->status_message("No value defined for subclassing model property '$subclassing_model_property'.  Skipping '$command_class'");
                    next;
                }
            }
            my $command;
            if ($command_class->isa('Genome::Model::EventWithRefSeq')) {
                if (ref($object)) {
                    unless ($object->can('ref_seq_id')) {
                        my $error_message = 'No support for the new Genome::Model::RefSeq objects. FIX ME!!!';
                        $self->cry_for_help($error_message);
                        die($error_message);
                    }
                    my $error_message = 'Expecting non-reference for EventWithRefSeq but got '. ref($object);
                    $self->cry_for_help($error_message);
                    die($error_message);
                }
                $command = $command_class->create(
                                                  model_id => $self->model_id,
                                                  ref_seq_id => $object,
                                              );
            } elsif ($command_class->isa('Genome::Model::EventWithReadSet')) {
                unless ($object->isa('Genome::Model::ReadSet')) {
                    my $error_message = 'Expecting Genome::Model::ReadSet object but got '. ref($object);
                    $self->cry_for_help($error_message);
                    die($error_message);
                }
                $command = $command_class->create(
                                                  read_set_id => $object->read_set_id,
                                                  model_id => $self->model_id,
                                              );
                $object->first_build_id($self->build_id);
            } elsif ($command_class->isa('Genome::Model::Event')) {
                $command = $command_class->create(
                                                  model_id => $self->model_id,
                                              );
            }
            unless ($command) {
                my $error_message = 'Problem creating subcommand for class '
                            . ' for object class '. ref($object)
                            . ' model id '. $self->model_id
                            . ': '. $command_class->error_message();
                $self->cry_for_help($error_message);
                die($error_message);
            }
            $command->parent_event_id($self->id);
            $command->event_status('Scheduled');
            $command->retry_count(0);
            $command->prior_event_id($prior_event_id);

            $prior_event_id = $command->id;
            push @scheduled_commands, $command;
            my $object_id;
            if (ref($object)) {
                $object_id = $object->id;
            } else {
                $object_id = $object;
            }
            $self->status_message('Scheduled '. $command_class .' for  '. $object_id
                                  .' event_id '. $command->genome_model_event_id ."\n");
        }
    }
    return @scheduled_commands;
}

sub _run_stage {
    my $self = shift;
    my @scheduled_commands = @_;
    if (@scheduled_commands) {
        my @dependency_ids = map {$_->lsf_job_id} @scheduled_commands;
        unless (Genome::Model::Command::RunJobs->execute(model_id => $self->model_id)) {
            $self->error_message('Failed to execute run-jobs for model '. $self->model_id);
            return;
        }
        unless($self->execute_with_bsub(dep_type=>'ended', dependency_expression => join(")&&ended(", @dependency_ids) )) {
            $self->error__message("Hello, I am the build module, and I was unable to schedule myself to run after my peeps.");
            return;
        }
        return 2;
    }
    return 1;
}

sub cry_for_help {
    my $self = shift;
    my $reason = shift;

    my $sendmail = "/usr/sbin/sendmail -t";
    my $from = "From: ssmith\@genome.wustl.edu\n";
    my $reply_to = "Reply-to: thisisafakeemail\n";
    my $subject = "Subject: Build failed, you suck\n";
    my $content = "This is the Build failure email. your build ". $self->id . " failed. \n$reason\n";
    my $to = "To: " . $self->user_name . '@genome.wustl.edu' . "\n";

    my $helpful_link1= "https://gscweb.gsc.wustl.edu/cgi-bin/solexa/genome-model-stage1.cgi?model-name=" . $self->model->name  .    "&refresh=1\n\n";
    my $helpful_link2= "https://gscweb.gsc.wustl.edu/cgi-bin/solexa/genome-model-stage2.cgi?model-name=" . $self->model->name  .    "&refresh=1\n";

    $content .= $helpful_link1 . $helpful_link2;



    open(SENDMAIL, "|$sendmail") or die "Cannot open $sendmail: $!";
    print SENDMAIL $reply_to;
    print SENDMAIL $from;
    print SENDMAIL $subject;
    print SENDMAIL $to;
    print SENDMAIL $content;
    close(SENDMAIL);
    return 1;
}


1;

