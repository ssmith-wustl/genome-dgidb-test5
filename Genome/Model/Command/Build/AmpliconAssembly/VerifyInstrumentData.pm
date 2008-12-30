package Genome::Model::Command::Build::AmpliconAssembly::VerifyInstrumentData;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Build::AmpliconAssembly::VerifyInstrumentData {
    is => 'Genome::Model::Event',
};

#< Subclassing...don't >#
sub _get_sub_command_class_name {
  return __PACKAGE__;
}

#< LSF >#
sub bsub_rusage {
    return "-R 'span[hosts=1]'";
}

#< The Beef >#
sub execute {
    my $self = shift;

    $self->_dump_unbuilt_instrument_data if $self->model->sequencing_center eq 'gsc';

    return $self->model->amplicons; # Error msg is on model if no amplicons
}

sub _dump_unbuilt_instrument_data {
    my $self = shift;

    $self->model->create_consed_directory_structure;
    
    for my $ida ( $self->model->unbuilt_instrument_data ) {
        unless ( $ida->instrument_data->dump_to_file_system )
        {
            $self->error_message(
                sprintf(
                    'Error dumping instrument data (%s <ID: %s) for model (%s <ID %s)',
                    $ida->instrument_data->run_name,
                    $ida->instrument_data->id,
                    $self->model->name,
                    $self->model->id,
                )
            );
            return;
        }
        $ida->first_build_id( $self->genome_model_event_id );
    }

    return 1;
}

1;

#$HeadURL$
#$Id$
