package Genome::Model::Event::Build::AmpliconAssembly::VerifyInstrumentData;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';

class Genome::Model::Event::Build::AmpliconAssembly::VerifyInstrumentData {
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
    
    return ( @links ) ? 1 : 0;
}

sub _link_instrument_data {
    my $self = shift;

    my @idas = $self->model->instrument_data_assignments;
    unless ( @idas ) {
        $self->error_message(
            sprintf(
                'No instrument data assigned to model for model (<Name> %s <Id> %s).',
                $self->model->name,
                $self->model->id,
            )
        );
        return;
    }

    for my $ida ( @idas ) {
        $self->_dump_unbuilt_instrument_data($ida) # error is in sub
            or return;
        unless ( $self->build->link_instrument_data( $ida->instrument_data ) ) {
            $self->error_message(
                sprintf(
                    'Error linking instrument data (%s <Id> %s) to model (%s <Id> %s)',
                    $ida->instrument_data->run_name,
                    $ida->instrument_data->id,
                    $self->model->name,
                    $self->model->id,
                )
            );
            return;
        }
    }

    return 1;
}

sub _dump_unbuilt_instrument_data {
    my ($self, $ida) = @_;

    unless ( $ida->instrument_data->dump_to_file_system ) {
        $self->error_message(
            sprintf(
                'Error dumping instrument data (%s <Id> %s) assigned to model (%s <Id> %s)',
                $ida->instrument_data->run_name,
                $ida->instrument_data->id,
                $self->model->name,
                $self->model->id,
            )
        );
        return;
    }

    return 1;
}

1;

#$HeadURL$
#$Id$
