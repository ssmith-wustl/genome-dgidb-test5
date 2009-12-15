package Genome::Model::Event::Build::Assembly::AssignReadSetToModel::454;

use strict;
use warnings;

use Genome;

class Genome::Model::Event::Build::Assembly::AssignReadSetToModel::454 {
    is => 'Genome::Model::Event::Build::Assembly::AssignReadSetToModel',
    has => [
            sff_file => {
                         calculate_from => ['instrument_data'],
                         calculate => q|
                             return $instrument_data->sff_file;
                         |,
                     },
        ]
 };

sub sub_command_sort_position { 40 }

sub help_brief {
    "Assigns the instrument data to the model by dumping the instrument data to the correct filesystem location."
}

sub help_synopsis {
    return <<"EOS"

EOS
}

sub help_detail {
    return <<"EOS"
Each instrument data assigned to an assembly model needs an sff file on the filesystem.
This step dumps the instrument data and verifies that the sff file exists and has size.
EOS
}

sub execute {
    my $self = shift;

    $DB::single = $DB::stopper;
    unless ($self->instrument_data->dump_to_file_system) {
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

