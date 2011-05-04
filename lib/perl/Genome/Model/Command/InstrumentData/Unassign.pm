package Genome::Model::Command::InstrumentData::Unassign;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';

class Genome::Model::Command::InstrumentData::Unassign {
    is => 'Genome::Model::Command',
    has => [
        model_id => {
            is => 'Integer', 
            doc => 'ID for the genome model to assign instrument data.'
        },
    ],
    has_optional => [
       instrument_data_id => {
            is => 'Number',
            doc => 'The unique ID of the instrument data to assign.  To assign multiple instrument data, enclose this param in quotes(\'), and separate the IDs by a space.'
        },
        instrument_data_ids => {
            is => 'Number',
            doc => 'The unique IDs of the instrument data to assign, enclosed in quotes(\'\'), and separated by a space.'
        },
        all => {
            is => 'Boolean',
            default => 0,
            doc => 'Unassign all available unassigned instrument data to the model.'
        },
    ],
    doc => "unassign instrument data to a model",
};

sub execute {
    my $self = shift;

    my @requested_actions = grep { 
        $self->$_ 
    } (qw/ instrument_data_id instrument_data_ids all /);

    if ( @requested_actions > 1 ) {
        $self->error_message('Multiple actions requested: '.join(', ', @requested_actions));
        return;
    }

    if ( $self->instrument_data_id ) { # unassign this
        return $self->_unassign_by_instrument_data_id($self->instrument_data_id);
    }
    elsif ( $self->instrument_data_ids ) { # unassign these
        return $self->_unassign_by_instrument_data_ids;
    }
    elsif ( $self->all ) { # unassign all
        return $self->_unassign_all_instrument_data;
    }
    else {
        $self->error_message('No action requested. Use --help for more information.');
        return;
    }
}

#< Unassign Instrument Data Id>#
sub _unassign_by_instrument_data_id {
    my ($self, $instrument_data_id) = @_;

    my $input = Genome::Model::Input->get(
        name => 'instrument_data',
        value_id => $instrument_data_id,
        model_id => $self->model_id,
    );

    if ( not $input ) {
        $self->status_message('Did not find instrument data input');
        return 1;
    }

    $input->delete;

    return 1;
}

sub _unassign_by_instrument_data_ids {
    my $self = shift;

    # Get the ids
    my @ids = split(/\s+/, $self->instrument_data_ids);
    unless ( @ids ) {
        $self->error_message("No instrument data ids found in instrument_data_id input: ". $self->instrument_data_ids);
        return;
    }

    for my $id ( @ids ) {
        $self->_unassign_by_instrument_data_id($id)
            or return;
    }

    return 1;
}

sub _unassign_all_instrument_data {
    my $self = shift;

    # Unassign all unassigned if requested 
    $self->status_message("Attempting to unassign all available instrument data");

    my @assigned_instrument_data = $self->model->instrument_data;

    unless ( @assigned_instrument_data ){
        $self->error_message("Attempted to unassign all instrument data that was assigned for model, but found none");
        return;
    }

    for my $data ( @assigned_instrument_data ) {
        my $id = $data->id;
        $self->_unassign_by_instrument_data_id($id)
            or return;
    }

    return 1;
}

1;
