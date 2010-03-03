package Genome::Model::Event::Build::MetagenomicComposition16s::PrepareInstrumentData::454;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';

class Genome::Model::Event::Build::MetagenomicComposition16s::PrepareInstrumentData::454 {
    is => 'Genome::Model::Event::Build::MetagenomicComposition16s::PrepareInstrumentData',
};

sub execute {
    my $self = shift;

    return 1;
    
    $self->_dump_and_link_instrument_data
        or return;

    my $amplicon_iterator = $self->build->amplicon_iterator
        or return;
    
    while ( my $amplicon = $amplicon_iterator->() ) {
        $self->_prepare_instrument_data_for_phred_phrap($amplicon)
            or return;
    }

    return 1;
}

#< Dumping/Linking Instrument Data >#
sub _dump_and_link_instrument_data {
    my $self = shift;

    unless ( $self->model->sequencing_center eq 'gsc' ) {
        # TODO add logic for other centers...
        return 1;
    }

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
        # dump
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
        $ida->first_build_id( $self->build_id );

        # link
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

1;

#$HeadURL$
#$Id$
