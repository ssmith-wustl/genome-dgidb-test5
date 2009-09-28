
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
        ],
    doc => "delete a genome model, all of its builds, and logs",
};

sub sub_command_sort_position { 4 }

sub help_synopsis {
    return <<"EOS"
genome-model remove FooBar
EOS
}

sub execute {
    my $self = shift;

    my $model = Genome::Model->get($self->model_id);
    unless ($model) {
        $self->error_message('No model found for model id '. $model->id);
        return;
    }
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
    unless ($model->delete) {
        $self->error_message('Failed to delete model id '. $model->id);
        return;
    }
    $self->status_message('Succesfully removed model id '. $model_id);
    return 1;
}




1;

