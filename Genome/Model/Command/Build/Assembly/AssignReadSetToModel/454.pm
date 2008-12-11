package Genome::Model::Command::Build::Assembly::AssignReadSetToModel::454;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Build::Assembly::AssignReadSetToModel::454 {
    is => 'Genome::Model::Command::Build::Assembly::AssignReadSetToModel',
    has => [
            sff_file => {
                         calculate_from => ['read_set'],
                         calculate => q|
                             return $read_set->sff_file;
                         |,
                     },
        ]
 };

sub sub_command_sort_position { 40 }

sub help_brief {
    "Assigns the read set to the model by dumping the read set data to the correct filesystem location."
}

sub help_synopsis {
    return <<"EOS"

EOS
}

sub help_detail {
    return <<"EOS"
Each read set assigned to an assembly model needs an sff file on the filesystem.
This step dumps the read set data and verifies that the sff file exists and has size.
EOS
}

sub execute {
    my $self = shift;

    $DB::single = $DB::stopper;
    unless ($self->read_set->dump_to_file_system) {
        $self->error_message('Failed to dump read set data to the filesystem');
        return;
    }
    return $self->verify_successful_completion;
}


sub verify_successful_completion {
    my $self = shift;

    unless (-e $self->sff_file) {
        $self->error_message('Failed to find sff file '. $self->sff_file);
        return;
    }
    unless (-s $self->sff_file) {
        $self->error_message('Sff file '. $self->sff_file .' is zero size.');
        return;
    }

    return 1;
}

1;

