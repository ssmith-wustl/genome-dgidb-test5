package Genome::Task;

use strict;
use warnings;

use Command::Dispatch::Shell;
use Genome;
use Digest::MD5 qw(md5_hex);
use Data::Dumper;
use JSON::XS;

class Genome::Task {
    table_name => 'GENOME_TASK',
    id_generator => '-uuid',
    id_by => {
        'id' => {is=>'Text', len=>64}
    },
    has => [
        command_class => {
            is=>'Text', 
            len=>255, 
            doc => 'Command class name'
        },
        status => {  # submitted, pending_execute, running, failed, succeeded
            is => 'Text', 
            default => 'submitted',
            len => 50, 
            doc => 'Task lifecycle status'
        },
        user_id => {
            is => 'Text', 
            len => 255, 
            doc => 'Submitting user'
        },
        time_submitted => {
            is => 'TIMESTAMP', 
            column_name => 'SUBMIT_TIME', 
            doc => 'Time task was submitted'
        },
    ],
    has_optional => [
        params => {
            is=>'Text', 
            doc => 'JSON encoded param hash'
        },
        stdout_pathname => {
            is => 'Text', 
            len => 255,
            doc => 'Resulting standard out path'
        },
        stderr_pathname => {
            is => 'Text', 
            len => 255, 
            doc => 'Resulting standard error path'
        },
        time_started => {
            is => 'TIMESTAMP',
            doc => 'Time execution started'
        },
        time_finished => { 
            is => 'TIMESTAMP', 
            doc => 'Time execution concluded'
        },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
    doc => 'scheduled tasks'
};

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_);
    
    my $cmd_object = $self->command_object;

    if (!$cmd_object) {
        $self->error_message("Could not get a command class, params may be invalid");
        $self->delete;
        return;
    }


    return $self;
}

sub command_object {
    my $self  = shift;
   
    my $cmd_class; 
    eval {
        $cmd_class = $self->command_class->class;
    };
    if ($@ || !$cmd_class) {
        $self->error_message(sprintf("Couldn't resolve command class: %s", $self->command_class));
        return;
    }

    my $vals = $self->_resolve_param_values(cmd_class=>$self->command_class,
                                            args => decode_json($self->params)); 
    
    if(!$vals) {
        $self->error_message(sprintf("Couldn't resolve params for %s based on params specified in the JSON", $self->command_class));
        return;
    }

    my $cmd = $cmd_class->create(%$vals);
    if (!$cmd) {
        $self->error_message("Could not resolve command class for params specified in the JSON");
        return;
    }
    
    return $cmd;
}


sub _resolve_param_values {
    my $class = shift;
    my %p = @_;

    my $cmd_class = $p{cmd_class};
    my $args = $p{args};

    my %resolved_values;

    my $cmd_class_meta = $cmd_class->__meta__;

    for my $arg_key (keys %$args) {
        my $property = $cmd_class_meta->property($arg_key);
        if (!$property) {
            $class->error_message("Invalid param $arg_key provided as a task parameter.");
            return;
        }
        my $type = $property->data_type;
        my $pre_value = $args->{$arg_key};
        if ($type =~ m/\:\:/) {
            my $value;
            if ($property->is_many) {
                my @v = Command::V2->resolve_param_value_from_text($pre_value, $type);
                $value = \@v;
            } else {
                $value = Command::V2->resolve_param_value_from_text($pre_value, $type);
            }

            if (!$value || (ref($value) eq 'ARRAY' && @$value == 0)) {
                $class->error_message("Failed to resolve any objects for param $arg_key with value $pre_value"); 
                return;
            }
            $resolved_values{$arg_key} = $value;
        } else {
            $resolved_values{$arg_key} = $pre_value;
        }
    }

    return \%resolved_values;
}

sub out_of_band_attribute_update {
    my $self = shift;
    my %attrs = @_;

    # we can't do out of band updates when tests are running because
    # we'd throw away the uncommitted cmd object.  so just update it
    # here.
    if ($ENV{'TEST_MODE'}) {
        for my $attr (keys %attrs) {
            $self->$attr($attrs{$attr});
        }
        return 1;
    }

    my $pid = UR::Context::Process->fork();
    if ($pid) {
        # in parent
        my $res = waitpid($pid, 0);
    } else {
        # don't want to commit anything done in the parent, so get a fresh start
        # also save our task because our cmd object in the child will get nuked when we rollback! 
        UR::Context->rollback;
        for my $attr (keys %attrs) {
            $self->$attr($attrs{$attr});
        }
        UR::Context->commit;
        exit(0); 
    }

    $self = UR::Context->current->reload(ref($self), $self->id);
    
    return 1;
}

1;
