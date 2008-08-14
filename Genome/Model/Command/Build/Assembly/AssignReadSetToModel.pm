package Genome::Model::Command::Build::Assembly::AssignReadSetToModel;

use strict;
use warnings;

use above "Genome";

class Genome::Model::Command::Build::Assembly::AssignReadSetToModel {
    is => 'Genome::Model::EventWithReadSet',
    has => [
            read_set_data_directory => {
                                        calculate_from => ['read_set'],
                                        calculate => q|
                                            return $read_set->full_path;
                                        |,
                                    },
            sff_file => {
                         calculate_from => ['read_set_data_directory','read_set'],
                         calculate => q|
                             return $read_set_data_directory .'/'. $read_set->seq_id .'.sff';
                         |,
                     },
        ]
 };

sub bsub_rusage {
    return '';
}

sub sub_command_sort_position { 40 }

sub help_brief {
    "assemble a genome"
}

sub help_synopsis {
    return <<"EOS"
genome-model build mymodel 
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

    my $read_set_data_directory = $self->read_set_data_directory;
    unless (-e $read_set_data_directory) {
        unless($self->create_directory($read_set_data_directory)) {
            $self->error_message("Failed to create directory '$read_set_data_directory'");
            return;
        }
    }
    unless (-e $self->sff_file) {
        unless ($self->read_set->run_region_454->dump_sff(filename => $self->sff_file)) {
            $self->error_message('Failed to dump sff_file to '. $self->sff_file);
            return;
        }
    }
    return 1;
}


1;

