package Genome::Model::Command::Build::Remove;

use strict;
use warnings;

use Genome;
use IO::File;
use File::Path;
use YAML;

class Genome::Model::Command::Build::Remove{
    is => 'Command',
    has_many => [
        builds => {
            is => 'String',
            doc => "The list of builds you would like to delete (along with their associated events and data directories)...input multiple numbers as comma-seperated with no spaces.",
        }
    ],
 };

sub sub_command_sort_position { 40 }

sub help_brief {
    "Deletes a build and related data and events."
}

sub help_synopsis {
    return <<"EOS"
genome-model build delete 123,124,125
EOS
}

sub help_detail {
    return <<"EOS"
Deletes a build. This means the build, events, and build data_directories are deleted.
EOS
}

sub execute {
    my $self = shift;

    my @builds_to_delete = $self->builds;
    unless (scalar(@builds_to_delete) > 0) {
        $self->status_message("No builds specified for deletion");
        return;
    }

    $self->status_message(scalar(@builds_to_delete) . " build(s) specified for deletion");

    my @data_directories_to_delete;
    for my $build_id (@builds_to_delete) {
        $self->status_message("Deleting records and data for build $build_id");
        
        # Get and delete the build entry
        my @build_entries = Genome::Model::Command::Build->get(build_id => $build_id);
        unless (scalar(@build_entries) == 1) {
            $self->error_message("Got " . scalar(@build_entries) . " build entries, expected 1");
            $self->rollback;
            return;
        }
        my $build = $build_entries[0];

        # Grab the data_directory and parent id before we delete the build
        my $data_directory = $build->data_directory;
        my $parent_id = $build->parent_event_id;
        unless ($data_directory) {
            $self->error_message("Data directory for build $build_id is not defined");
        }

        # Backup the data before we delete
        $self->status_message("Backing up events as a YAML... and zipping and archiving data_directory");
        $self->backup_data_for_build($build_id);
        
        # Delete it
        $self->status_message("Deleting build entry");
        $build->delete;

        # Get and delete the parent event entry
        if ($parent_id) {
            my @parent_entries = Genome::Model::Command::Event->get($parent_id);
            unless (scalar(@parent_entries) == 1) {
                $self->error_message("Got " . scalar(@parent_entries) . " parent entries, expected 1");
                $self->rollback;
                return;
            }
            my $parent_entry = $parent_entries[0];
            $self->status_message("Deleting parent event");
            $parent_entry->delete;
        } else {
            $self->status_message("No parent event found, so no delete necessary");
        }

        push @data_directories_to_delete, $data_directory;
    }

    # If they decide to commit, remove the directories
    $DB::single=1;
    if ($self->commit) {
        # Now... since all the database deletions went well, cleanup the build data_directories
        $self->status_message("Everything seems to have gone well, deleting all of the data_directories of the deleted builds");
        for my $data_directory (@data_directories_to_delete) {
            $self->status_message("Deleting $data_directory");
            rmtree($data_directory);
        }
        $self->status_message("Mission accomplished.");
        return 1;
    } else {
        return;
    }

}

# warns and rolls back
# FIXME: We should not explicitly roll back here... this needs to be restructured
sub rollback {
    my $self = shift;

    $self->warning_message("Problems encountered... rolling back and deleting backup files");
    my @builds = $self->builds;
    my $class = $self->class;
    UR::Context->rollback;

    # Delete the backup files, since we rolled back
    for my $build (@builds) {
        unlink($class->backup_data_file_name_for_build($build));
        unlink($class->backup_object_file_name_for_build($build));
    }
    
    return 1;
}

# Asks for confirmation and returns true if it should commit, undef if not 
sub commit { 
    my $self = shift;

    my $choice = '';
    while ($choice ne "Y" and $choice ne "N") {
        $self->status_message("Everything seems ok... but this is irreversible. Really commit these deletions? (Y/N)");
        $choice = <STDIN>;
        chomp($choice);
    }

    if ($choice eq "Y") {
        return 1;
    } else {
        $self->rollback;
        return;
    }
}
# Backs up object to be deleted for a single build as a yaml file 
# and backs up the data directory of the build
sub backup_data_for_build {
    my $self = shift;
    my $build_id = shift;

    my $build = Genome::Model::Command::Build->get($build_id);
    unless ($build) {
        $self->error_message("Could not get build for build id $build_id");
        return;
    }
    # back up the objects as yaml files
    my $yaml_file_name = $self->backup_object_file_name_for_build($build_id);
    
    my $fh = IO::File->new($yaml_file_name,'w');
    unless ($fh) {
        $self->error_message('Failed to create file handle for file '. $yaml_file_name);
        return;
    }
    print $fh $self->yaml_string($build_id);
    $fh->close;
 
    # back up the data directory as an archived tbz file
    my $archive_file = $self->backup_data_file_name_for_build($build_id);
    my $build_data_directory = $build->data_directory;

    if (($build_data_directory)&&(-d $build_data_directory)) {
        my $cmd = 'tar --bzip2 --preserve --create --file '. $archive_file .' '. $build_data_directory;
        my $rv = system($cmd);
        unless ($rv == 0) {
            $self->error_message('Failed to create archive of model '. $self->id .' with command '. $cmd);
            return;
        }
    } elsif (!$build_data_directory) {
        $self->status_message("No build data directory defined for build $build_id");
    } else {
        $self->status_message("Build data directory $build_data_directory does not exist! Can not back up.");
    }

    return 1;
}

# Returns a string with the yaml-ized backup data of this build and its parent events
sub yaml_string {
    my $self = shift;
    my $build_id = shift;

    unless ($build_id) {
        $self->error_message("No build id passed into yaml_string");
        return;
    }

    # Back up the build
    my $build = Genome::Model::Command::Build->get($build_id);
    unless ($build) {
        $self->error_message("Could not get build for build id $build_id");
        return;
    }
    my $string = YAML::Dump($build);

    # Backup parent event if there is one
    my $parent_event_id = $build->parent_event_id;
    if ($parent_event_id) {
        my $parent_event = Genome::Model::Event->get($parent_event_id);
        unless ($parent_event) {
            $self->error_message("Could not get parent event for parent_event_id " . $build->parent_event_id);
            return;
        }
        $string .= YAML::Dump($parent_event);
    }

    return $string;
}

# Returns the file path for the yaml file backup for the given build
sub backup_basename_for_build { 
    my $self = shift;
    my $build_id = shift;

    my $build = Genome::Model::Command::Build->get($build_id);
    unless ($build) {
        $self->error_message("Could not get build for build id $build_id");
        return;
    }

    my $model = Genome::Model->get($build->model_id);

    unless ($model) {
        $self->error_message("Could not get model for build $build_id");
        return;
    }

    my $model_data_dir = $model->data_directory;
    my $backup_file = $model_data_dir . "/build$build_id";
    
    return $backup_file;
}

# Returns the path of the yaml object backup file
sub backup_object_file_name_for_build {
    my $self = shift;
    my $build_id = shift;

    my $basename = $self->backup_basename_for_build($build_id);
    return unless $basename;

    my $object_file_path = "$basename.yaml";
    return $object_file_path;
}

# Returns the path of the data directory  backup file
sub backup_data_file_name_for_build {
    my $self = shift;
    my $build_id = shift;

    my $basename = $self->backup_basename_for_build($build_id);
    return unless $basename;

    my $data_file_path = "$basename.tbz";
    return $data_file_path;
}

1;

