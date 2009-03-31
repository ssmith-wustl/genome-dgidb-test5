package Genome::Model::Command::Build::AmpliconAssembly::VerifyInstrumentData;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';

class Genome::Model::Command::Build::AmpliconAssembly::VerifyInstrumentData {
    is => 'Genome::Model::Event',
};

sub bsub_rusage {
    return "-R 'span[hosts=1]'";
}

sub execute {
    my $self = shift;

    if ( $self->model->sequencing_center eq 'gsc' ) {
        $self->_link_instrument_data
            or return;
    } # TODO add logic for other centers...

    my @links = glob($self->build->chromat_dir.'/*');
    
    return ( @links )
    ? 1
    : 0;
}

sub _link_instrument_data {
    my $self = shift;

    my $chromat_dir = $self->build->chromat_dir;
    for my $ida ( $self->model->instrument_data_assignments ) {
        $self->_dump_unbuilt_instrument_data($ida)
            or return;
        $self->build->link_instrument_data( $ida->instrument_data )
            or return;
    }

    return 1;
}

sub _dump_unbuilt_instrument_data {
    my ($self, $ida) = @_;

    unless ( $ida->first_build_id ) {
        unless ( $ida->instrument_data->dump_to_file_system ) {
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
        $ida->first_build_id( $self->build_id );
    }
    
    return 1;
}

1;

#$HeadURL$
#$Id$
