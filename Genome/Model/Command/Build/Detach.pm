# FIXME ebelter
#  rename?
#  may not really work - ask eclark
package Genome::Model::Command::Build::Detach;

use strict;
use warnings;

use Genome;
use POE::Component::IKC::ClientLite;

class Genome::Model::Command::Build::Detach {
    is => ['Genome::Model::Command'],
    has => [
            build_id => {
                         is => 'Number',
                         doc => 'The id of the build in which to detach an event',
                         is_optional => 1,
                     },
            build   => {
                        is => 'Genome::Model::Build',
                        id_by => 'build_id',
                        is_optional => 1,
                    },
            event_id => { 
                is => 'Number',
                doc => 'The id of the event to detach'
            },
            event => {
                is => 'Genome::Model::Event',
                id_by => 'event_id'
            }
        ],
};

sub help_detail {
    "This command will allow a build to proceed without waiting for one of the events to complete";
}

sub sub_command_sort_position { 4 }

sub execute {
    my $self = shift;
    my $model = $self->model;
    unless ($self->build_id) {
        $self->build_id($model->current_running_build_id);
    }
    my $build = $self->build;
    unless ($build) {
        $self->error_message('Build not found for model id '. $self->model_id .' and build id '. $self->build_id);
        return;
    }
    my $build_event = $build->build_event;
    unless ($build_event) {
        $self->error_message('No build event found for build '. $self->build_id);
        return;
    }

    my $detach_event = $self->event;
    unless ($detach_event) {
        $self->error_message('Event ' . $self->event_id . ' not found for build id ' . $self->build_id);
        return;
    }

    unless (-e $build->data_directory . '/build.xml') {
        $self->error_message('Build (' . $build->id . ') does not support this feature');
        return;
    }

    my $server_location_file = $build->data_directory . '/server_location.txt';
    unless (-e $server_location_file) {
        $self->error_message('Server location file is missing for build ' . $self->build_id);
        $self->error_message('Verify that build is currently running with bjobs');
        return;
    }

    my $host;
    my $port;
    {
        open SLF, '<' . $server_location_file;
        while (my $line = <SLF>) {
            chomp $line;
            ($host,$port) = split(':',$line);
        }
        close SLF;
    }
    
    unless ($host && $port) {
        $self->error_message('Cannot find server for this build.  It may have exited prematurely');
        return;
    }

    $self->status_message("Workflow Server: " . $host . ':' . $port);

    $self->status_message("Event Id: " . $detach_event->id);
    my $opname = $detach_event->command_name_brief . ' ' . $detach_event->id;
    $self->status_message("Operation Name: " . $opname);

    my $poe = create_ikc_client(ip => $host, port => $port);

    unless ($poe) {
        $self->error_message("Cant connect to $host:$port.");
        return;
    }    
    $self->status_message("Connected to server");
    
    my $result;
    my $status_code;
    my $return_value;
    
    $result = $poe->call("workflow/eval",[q{
        my $i = Workflow::Operation::Instance->get(name => '} . $opname . q{');
        
        return unless $i;
        return { id => $i->id, status => $i->status };
    },0]) or die $poe->error;

    ($status_code,$return_value) = @$result;

    my $operation_id = $return_value->{id};
    my $operation_status = $return_value->{status};
    
    $self->status_message("Operation Id <$operation_id> Status <$operation_status>");

    $result = $poe->call("workflow/eval",[q{
        my $i = Workflow::Operation::Instance->get( name => '} . $opname . q{');
        
        return unless $i;
        
        $i->orphan(result => 1);
    
        return $i->id;
    },0]) or die $poe->error;

    if ($result->[1]) {
        $self->status_message("Triggered orphan state on the running workflow");
    }

    $self->status_message("Disconnecting from server");
    $poe->disconnect;


    return 1;
}


1;

