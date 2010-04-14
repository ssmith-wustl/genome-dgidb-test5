
package Genome::Model::Command::Remove;

use strict;
use warnings;

use Genome;
use Cwd;

class Genome::Model::Command::Remove {
    is => 'Genome::Model::Command',
    has => [
        model_id => {
                        is => 'Integer',
                        shell_args_position => 1,
                        doc => 'The model_id of the model you wish to remove',
                    },
        archive  => {
                        is => 'Boolean',
                        default_value => 0,
                        doc => 'A boolean flag to archive model data.(default_value=0)',
                    },
        force_delete => {
                            is => 'Boolean',
                            default_value => 0,
                            doc => 'A boolean flag to force model delete.(default_value=0)',
                        },
         keep_model_directory => {
                            is => 'Boolean',
                            default_value => 0,
                            doc => 'A boolean flag to allow the retention of the model directory after the model is purged from the database.(default_value=0)',
         },
         keep_build_directories => {
                            is => 'Boolean',
                            default_value => 0,
                            doc => 'A boolean flag to allow the retention of the model directory after the model is purged from the database.(default_value=0)',
         }
    ],
    doc => "delete a genome model, all of its builds, and logs",
};

sub sub_command_sort_position { 4 }

sub help_synopsis {
    return <<"EOS"
genome model remove 12345 
EOS
}

sub execute {
    my $self = shift;
    
    my $keep_model_directory = $self->keep_model_directory;
    my $keep_build_directories = $self->keep_build_directories;

    $DB::single = 1;

    my $model = Genome::Model->get($self->model_id);
    unless ($model) {
        $self->error_message('No model found for model id '. $self->model_id);
        return;
    }
   
    my $subject = $model->subject;
    my $subject_name = ($subject ? $subject->name : $model->subject_name);
    my $subject_id = ($subject ? $subject->id : $model->subject_id);

    $self->status_message(
        "Removing model " . $model->name . " (" . $model->id 
        . ") for " . $subject_name . " (" . $subject_id . ")\n"
    );

    unless ($self->force_delete) {
        my $response = $self->_ask_user_question('Are you sure you want to remove model id '. $model->id .'?');
        unless ($response eq 'yes') {
            $self->status_message('Not deleting model id '. $model->id);
            return 1;
        }
    }

    if ($self->archive) {
        my $data_directory = $model->data_directory;
        $self->status_message('Archiving model data directory: '. $data_directory);
        my $db_objects_dump_file = $data_directory .'/data_dump.yaml';
        my $fh = IO::File->new($db_objects_dump_file,'w');
        unless ($fh) {
            $self->error_message('Failed to create file handle for file '. $db_objects_dump_file);
            return;
        }
        print $fh $model->yaml_string;
        $fh->close;
        my $cwd = getcwd;
        my ($filename,$dirname) = File::Basename::fileparse($data_directory);
        $filename =~ s/^-/\.\/-/;
        unless (chdir $dirname) {
            $self->error_message('Failed to change directories to '. $dirname);
            return;
        }
        $self->status_message('chdir to '. $dirname);
        my $cmd = 'tar --bzip2 --preserve --create --file '. $model->resolve_archive_file .' '. $filename;
        $self->status_message('Running: '. $cmd);
        my $rv = system($cmd);
        unless ($rv == 0) {
            $self->error_message('Failed to create archive of model id '. $model->id .' with command '. $cmd);
            return;
        }
        unless (chdir $cwd) {
            $self->error_message('Failed to change directories to '. $cwd);
            return;
        }
        $self->status_message('chdir to '. $cwd);
    }
    my $model_id = $model->id;
    unless ($model->delete(keep_model_directory => $keep_model_directory, keep_build_directories => $keep_build_directories)) {
        $self->error_message('Failed to delete model id '. $model->id);
        return;
    }
    $self->status_message('Succesfully removed model id '. $model_id);
    return 1;
}




1;

