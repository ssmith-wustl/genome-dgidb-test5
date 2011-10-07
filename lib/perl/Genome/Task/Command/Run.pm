package Genome::Task::Command::Run;

use warnings;
use strict;
use Genome;
use JSON::XS;
use File::Path;

class Genome::Task::Command::Run {
    is => 'Command::V2',
    has => [
        task => {
            is => 'Genome::Task',
            doc => 'Task to run.  Resolved from command line via text string',
            shell_args_position => 1,
        },
        output_basedir => {
            is => 'String',
            doc => 'Directory to put stdout/stderr',    
            is_optional => 1,
        }
    ],
};

sub execute {
    my $self = shift;
    
    my $class_object;
    eval {$class_object = $self->task->command_class->class};
    if (!$class_object) {
        $self->error_message(sprintf("Failed to execute, %s couldn't be loaded", $self->task->command_class));
        return $self->handle_failure;
    }

    my $cmd_object = $self->task->command_object;
    if (!$cmd_object) {
        $self->error_message(sprintf("Failed to execute, %s couldn't be instantiated", $self->task->command_class));
        return $self->handle_failure;
    }

    my $old_stdout;
    my $old_stderr;
    my $log_basedir;
    if ($self->output_basedir) {
        $log_basedir = $self->output_basedir;
        if (!-d $log_basedir) {
            unless(mkpath($log_basedir)) {
                $self->error_message("Couldn't create output dir $log_basedir");
                return;
            }
        }
         
        open ($old_stdout, ">&STDOUT");
        open ($old_stderr, ">&STDERR");
       
        open (STDERR, ">$log_basedir/".$self->task->id .".stderr"); 
        open (STDOUT, ">$log_basedir/".$self->task->id .".stdout"); 
    }
        
    my $result;
    eval {
        my %attrs_to_update = (status => 'running', time_started => UR::Time->now());
        if ($self->output_basedir) {
            $attrs_to_update{stdout_pathname} = $log_basedir. "/" . $self->task->id. "/stdout"; 
            $attrs_to_update{stderr_pathname} = $log_basedir. "/" . $self->task->id. "/stderr"; 
        }

        $self->task->out_of_band_attribute_update(%attrs_to_update);
        $result = $cmd_object->execute;
    };
    
    if ($@ || !$result) {
        $self->error_message("COMMAND FAILURE:  $@ -- " . $cmd_object->error_message);
        $self->task->status("failed");
    } else {
        $self->task->status("succeeded");
    }

    if ($self->output_basedir) {
        open (STDOUT, ">&", $old_stdout);
        open (STDERR, ">&", $old_stderr);
    }
    
    $self->task->time_finished(UR::Time->now);

    return $result;
}

1;
