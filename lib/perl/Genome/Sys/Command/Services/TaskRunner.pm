package Genome::Sys::Command::Services::TaskRunner;

use warnings;
use strict;
use Genome;
use JSON::XS;
use File::Path;

class Genome::Sys::Command::Services::TaskRunner {
    is => 'Command',
    doc => 'Runner for scheduled tasks',
    has => [
        output_basedir => {
            is => 'String',
            doc => 'Directory to put stdout/stderr from run jobs',    
            is_optional => 1,
        },
        restart_file => {
            is => 'String',
            doc => 'File to watch for restart trigger - touch this file to restart daemon',
            is_optional => 1
        },
        _restart_file_mtime => {
            is => 'Integer',
            is_optional => 1,
            is_transient => 1
        }
    ],
};

sub execute {
    my $self = shift;
        
    if ($self->restart_file) {
        $self->_restart_file_mtime(0);
        
        if (-f $self->restart_file) {
            $self->_restart_file_mtime((stat($self->restart_file))[9]);
        }
    }

    while (1) {
        $self->task_loop();
        $self->check_restart_loop() if $self->restart_file;
        sleep 15;
    }

}


sub task_loop {
    my $self = shift;
    
    my $ds = $UR::Context::current->resolve_data_sources_for_class_meta_and_rule(Genome::Task->__meta__);
    my $dbh = $ds->get_default_dbh;

    # get lock on pending jobs and bypass object cache
    my $res = $dbh->selectall_arrayref("SELECT id FROM genome_task WHERE status='submitted' FOR UPDATE");
   
    if (@$res > 0) { 
        my ($id) = $res->[0]->[0];
         
        my $task = Genome::Task->get($id); 
        # before we fork, we'll drop the db connection and lose our lock.  
        # so first, update the status so that nobody else takes it in the meantime.
        $task->status("pending_execute");
        UR::Context->commit;
        
        my $pid = UR::Context::Process->fork();
        if (!$pid) {
           $self->status_message("Forked $$, running $id");
           Genome::Task::Command::Run->create(task=>$task, output_basedir=>$self->output_basedir)->execute; 
           UR::Context->commit;
           exit(0);
        } else {
           $task->unload; 
           waitpid($pid, 0);
        }
    }
     
    UR::Context->commit;
}

sub check_restart_loop() {
    my $self = shift;

    if (-f $self->restart_file) {
        my $mtime = (stat($self->restart_file))[9];
        if ($mtime > $self->_restart_file_mtime) {
            $self->status_message("Restart file updated. Restarting as requested.");
            exec("genome model services task-runner");
        }
    }
    
}


1;
