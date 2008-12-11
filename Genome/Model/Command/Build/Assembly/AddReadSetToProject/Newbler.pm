package Genome::Model::Command::Build::Assembly::AddReadSetToProject::Newbler;

use strict;
use warnings;

use Genome;
use Data::Dumper;

class Genome::Model::Command::Build::Assembly::AddReadSetToProject::Newbler {
    is => 'Genome::Model::Command::Build::Assembly::AddReadSetToProject',
    has => [
            sff_file => {via => 'read_set'},
            sff_link => {
                         doc => 'The symlink created by newbler after the read set is added to the newbler project',
                         calculate_from => ['model', 'read_set'],
                         calculate => q|
                             return $model->sff_directory .'/'. $read_set->seq_id .'.sff';
                         |,

                     }
        ],
};

sub bsub_rusage {
    return "-R 'select[type=LINUX64]'";
}

sub sub_command_sort_position { 40 }

sub help_brief {
    "add read set to an assembly of a genome"
}

sub help_synopsis {
    return <<"EOS"
genome-model build assembly add-read-set-to-project 
EOS
}

sub help_detail {
    return <<"EOS"
One build of a given assembly model.
EOS
}


sub execute {
    my $self = shift;

    $DB::single = $DB::stopper;

    my $model = $self->model;

    my $assembly_directory = $model->assembly_directory;
    my $sff_directory = $model->sff_directory;
    unless (-d $assembly_directory && -d $sff_directory) {
	my %new_assembly_params = (
				   dir => $model->data_directory,
				   version => $model->assembler_version,
                               );

        my $new_assembly = Genome::Model::Tools::454::Newbler::NewAssembly->create( %new_assembly_params );
        unless ($new_assembly->execute) {
            # May need to add locking to prevent more than one event from creating project
            # Currently just double check that the project still doesn't exist after a few seconds
            sleep 5;
            unless (-d $assembly_directory && -d $sff_directory) {
                $self->error_message("Failed to create new assembly '$assembly_directory'");
                return;
            }
        }
        chmod 02775, $assembly_directory;
        chmod 02775, $sff_directory;
    }

    my %add_run_params = (
			  dir => $model->data_directory,
			  runs => [$self->sff_file],
			  is_paired_end => $self->read_set->is_paired_end,
			  version => $model->assembler_version,
                      );

    my $add_run = Genome::Model::Tools::454::Newbler::AddRun->create( %add_run_params );
    unless($add_run->execute) {
        $self->error_message('Failed to add run '. $self->id ." to project $assembly_directory");
        return;
    }
    return $self->verify_successful_completion;
}

sub verify_successful_completion {
    my $self = shift;

    my $model = $self->model;

    unless (-d $model->assembly_directory) {
        $self->error_message('Failed to create assembly directory: '. $model->assembly_directory);
        return;
    }
    unless (-d $model->sff_directory) {
        $self->error_message('Failed to create sff directory: '. $model->sff_directory);
        return;
    }
    unless (-l $self->sff_link ) {
        $self->error_message('Symlink '. $self->sff_link .' not created for newbler project');
        return;
    }
    return 1;
}

1;

