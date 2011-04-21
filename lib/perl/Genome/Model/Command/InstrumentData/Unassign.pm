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
        capture => {
            is => 'Boolean',
            default => 0,
            doc => 'Only assign capture data',
        },
        capture_target => {
            is => 'String',
            doc => 'Only assign capture data with the specified target (implies --capture)',
        },
    ],
    doc => "unassign instrument data to a model",
};

sub create {
    my ($class, %params) = @_;

    my $self = $class->SUPER::create(%params)
        or return;

    if (defined($self->capture_target())) {
        $self->capture(1);
    }
    
    if ($self->capture()) {
        $self->all(1);
    }
    
    my @requested_actions = grep { 
        $self->$_ 
    } (qw/ instrument_data_id instrument_data_ids all /);
    
    if ( @requested_actions > 1 ) {
        $self->error_message('Multiple actions requested: '.join(', ', @requested_actions));
        $self->delete;
        return;
    }
    
    $self->_verify_model
        or  return;

    return $self;
    
}

sub execute {
    my $self = shift;

    if ( $self->instrument_data_id ) { # assign this
        return $self->_unassign_by_instrument_data_id($self->instrument_data_id);
    }
    elsif ( $self->instrument_data_ids ) { # assign these
        return $self->_unassign_by_instrument_data_ids;
    }
    elsif ( $self->all ) { # assign all
        return $self->_unassign_all_instrument_data;
    }

    return $self->_list_compatible_instrument_data; # list compatable
}

#< Unassign Instrument Data Id>#
sub _unassign_by_instrument_data_id {
    my ($self, $instrument_data_id) = @_;

    my $input = Genome::Model::Input->get(
        name => 'instrument_data',
        value_id => $instrument_data_id,
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

    my @assigned_instrument_data = $self->model->assigned_instrument_data;

    unless ( @assigned_instrument_data ){
        $self->error_message("Attempted to unassign all instrument data that was assigned for model, but found none");
        return;
    }

    my $requested_capture_target = $self->capture_target();
  ID: for my $id ( @assigned_instrument_data ) {

        my $id_capture_target;
        if ($id->can('target_region_set_name')) {
            $id_capture_target = $id->target_region_set_name();
        }

        if ($self->capture()) {

            unless (defined($id_capture_target)) {
                next ID;
            }

            if (defined($requested_capture_target)) {
                unless ($id_capture_target eq $requested_capture_target) {
                    next ID;
                }
            }

        }
        else {

            if (defined($id_capture_target)) {
                next ID;
            }
        }
        $self->_unassign_by_instrument_data_id($id)
            or return;
    }

    return 1;
}

sub _list_compatible_instrument_data {
    my $self = shift;

    my @compatible_instrument_data = $self->model->compatible_instrument_data;
    my @assigned_instrument_data = $self->model->assigned_instrument_data;
    my @unassigned_instrument_data = $self->model->unassigned_instrument_data;

    $self->status_message(
        sprintf(
            'Model (<name> %s <subject_name> %s): %s assigned and %s unassigned of %s compatible instrument data',
            $self->model->name,
            $self->model->subject_name,
            scalar @assigned_instrument_data,
            scalar @unassigned_instrument_data,
            scalar @compatible_instrument_data
        )
    );

    if (@unassigned_instrument_data) {
        my $lister = Genome::Model::Command::InstrumentData::List->create(
            unassigned=>1,
            model_id => $self->model->id
        );

        return $lister->execute;
    }

    return 1;
}

1;

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/trunk/Genome/Model/Command/InstrumentData/Unassign.pm $
#$Id: Unassign.pm 48952 2009-07-16 02:12:44Z mjohnson $
