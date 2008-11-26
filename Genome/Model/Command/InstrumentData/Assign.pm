package Genome::Model::Command::InstrumentData::Assign;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::InstrumentData::Assign {
    is => 'Genome::Model::Event',
    has => [
        model_id => {
            is => 'Integer', 
            doc => 'ID for the genome model to assign instrument data.'
        },
    ],
    has_optional => [
        instrument_data_id => {
            is => 'Number',
            doc => 'The unique ID of the instrument data to assign.'
        },
        all => {
            is => 'Boolean',
            default => 0,
            doc => 'Assign all available unassigned instrument data to the model.'
        },
    ],
};

#########################################################

sub help_brief {
    return "Assign instrument data to a model";
}

sub help_detail {
    return help_brief();
}

#########################################################

sub execute {
    my $self = shift;

    $self->_verify_model
        or return;
    
    # We got an id, assign this one only
    if ( defined $self->instrument_data_id ) {
        my $instrument_data = Genome::InstrumentData->get( $self->instrument_data_id );
        unless ( $instrument_data ) {
            $self->error_message( sprintf('Failed to find specified instrument data for id (%s)', $self->read_set_id) );
            return;
        }
        return $self->_assign_instrument_data($instrument_data);
    } 

    # Assign all unassigned if requested 
    if ( $self->all ) {
        $self->status_message("Attempting to assign all availble instrument data");
        my @unassigned_instrument_data = $self->model->unassigned_instrument_data;
        unless ( @unassigned_instrument_data ){
            $self->error_message("Attempted to assign all instrument data that was unassigned for model, but found none");
            return;
        }
        for my $id ( @unassigned_instrument_data ) { 
            $self->_assign_instrument_data($id)
                or return;
        }

        return 1;
    }

    if ( 1 ) { #$self->list_available ) {
        # List available
        my @available_instrument_data = $self->model->compatible_instrument_data;
        unless ( @available_instrument_data ) {
            $self->status_message( 
                sprintf(
                    'No compatible instrument data found for model (<name> %s <subject name> %s)',
                    $self->model->name, 
                    $self->model->subject_name,
                ) 
            );
            return;
        }
        print Data::Dumper::Dumper(\@available_instrument_data);
    }

    return 1;
}

sub _assign_instrument_data {
    my ($self, $instrument_data) = @_;

    # Check if already assigned
    my $existing_ida = Genome::Model::InstrumentDataAssignment->get(
        model_id => $self->model->id,
        instrument_data_id => $instrument_data->id
    );
    if ( $existing_ida ) {
        $self->status_message(
            sprintf(
                'Instrument data (id<%s> name<%s>) has already been assigned to model (id<%s> name<%s>).',
                $existing_ida->instrument_data_id,
                $existing_ida->run_name,
                $self->model->id,
                $self->model->name,
            )
        );
        return 1;
    }

    my $ida = Genome::Model::InstrumentDataAssignment->create(
        model_id => $self->model->id,
        instrument_data_id => $instrument_data->id,
        #first_build_id  => undef,  # set when we run the first build with this read set
    );

    unless ( $ida ) { 
        $self->error_message(
            sprintf(
                'Failed to add instrument data (id<%s> name<%s>) to model (id<%s> name<%s>).',
                $instrument_data->id,
                $instrument_data->run_name,
                $self->model->id,
                $self->model->name,
            )
        );
        return;
    }

    $self->status_message(
        sprintf(
            'Instrument data (id<%s> name<%s>) assigned to model (id<%s> name<%s>)',
            $instrument_data->id,
            $instrument_data->run_name,
            $self->model->id,
            $self->model->name,
        )
    );

    return 1;
}

1;

#$HeadURL$
#$Id$
