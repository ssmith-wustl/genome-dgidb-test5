package Genome::Model::Command::AddReads::AssignRun::Solexa;

use strict;
use warnings;

use above "Genome";
use File::Path;
use GSC;

class Genome::Model::Command::AddReads::AssignRun::Solexa {
    is => 'Genome::Model::Event',
    has => [ 
        model_id   => { is => 'Integer', is_optional => 0, doc => 'the genome model on which to operate' },
    ]
};

sub help_synopsis {
    return <<"EOS"
    genome-model add-reads assign-run solexa --model-id 5 --run-id 10
EOS
}

sub help_brief {
    "Creates the appropriate items on the filesystem for a new Solexa run"
}

sub help_detail {                           
    return <<EOS 
This command is normally run automatically as part of "add-reads assign-run"
when it is determined that the run is from Solexa.  
EOS
}

sub execute {
    my $self = shift;

    $DB::single=1;

    my $model = Genome::Model->get(id => $self->model_id);

    my $run = Genome::RunChunk->get(id => $self->run_id);
    unless ($run) {
        $self->error_message("Did not find run info for run_id " . $self->run_id);
        return 0;
    }

    unless (-d $model->data_parent_directory) {
        eval { mkpath $model->data_parent_directory };
				if ($@) {
					$self->error_message("Couldn't create run directory path $model->data_parent_directory: $@");
					return;
				}
        unless(-d $model->data_parent_directory) {
            $self->error_message("Failed to create data parent directory: ".$model->data_parent_directory. ": $!");
            return;
        }
    }

    my $run_dir = $self->resolve_run_directory;
    if (-d $run_dir) {
        $self->status_message("Run directory $run_dir already exists");
        $self->event_status('completed');
    }
    
    eval { mkpath($run_dir) };
    if ($@) {
        $self->error_message("Couldn't create run directory path $run_dir: $@");
        return;
    }

    return 1;
}

1;

