# FIXME ebelter
#  Long: Remove or update to use inputs as appropriate.
#
package Genome::Model::Command::InstrumentData::Assign;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';

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
            doc => 'The unique ID of the instrument data to assign.  To assign multiple instrument data, enclose this param in quotes(\'), and separate the IDs by a space.'
        },
        flow_cell_id => {
            is => 'Number',
            doc => 'Assigns all lanes in the given flowcell whose sample_name matches the model\'s subject name'       
        },
        instrument_data_ids => {
            is => 'Number',
            doc => 'The unique IDs of the instrument data to assign, enclosed in quotes(\'\'), and separated by a space.'
        },
        all => {
            is => 'Boolean',
            default => 0,
            doc => 'Assign all available unassigned instrument data to the model.'
        },
        filter => {
            is => 'Text',
            valid_values => ['forward-only','reverse-only'],
        },
        force => {
            is => 'Boolean',
            default => 0,
            doc => 'Allow assignment of data even if the subject does not match the model',
        }
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

sub create { 
    my ($class, %params) = @_;

    my $self = $class->SUPER::create(%params)
        or return;

    my @requested_actions = grep { 
        $self->$_ 
    } (qw/ flow_cell_id instrument_data_id instrument_data_ids all /);

    if ( @requested_actions > 1 ) {
        $self->error_message('Multiple actions requested: '.join(', ', @requested_actions));
        $self->delete;
        return;
    }

    $self->_verify_model
        or  return;

    return $self;

}

#TODO:put this logic in Genome::Model::assign_instrument_data() and turn this command into a thin wrapper
sub execute {
    my $self = shift;
    $DB::single=1;
    if ( $self->instrument_data_id ) { # assign this
        return $self->_assign_by_instrument_data_id;
    }
    elsif ( $self->instrument_data_ids ) { # assign these
        return $self->_assign_by_instrument_data_ids;
    }
    elsif ( $self->flow_cell_id ) { #assign all instrument data ids whose sample name matches the models subject name and flow_cell_id matches the flow_cell_id given by the user
        my $flow_cell_id = $self->flow_cell_id;
        my $sample_name = $self->model->subject_name;
        my @instrument_data_ids = `sqlrun "select seq_id from solexa_lane_summary WHERE SAMPLE_NAME ='$sample_name' AND FLOW_CELL_ID = '$flow_cell_id' ORDER BY flow_cell_id, lane" --instance warehouse --parse`;
        chomp @instrument_data_ids;
        unless ( @instrument_data_ids ){
            $self->error_message("Found no matching instrument data for flowcell id $flow_cell_id");
            return;
        }
        $self->instrument_data_ids( join (' ',@instrument_data_ids));
        return $self->_assign_by_instrument_data_ids;        
    }
    elsif ( $self->all ) { # assign all
        return $self->_assign_all_instrument_data;
    }

    return $self->_list_compatible_instrument_data; # list compatable
}

#< Assign Instrument Data >#
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
                'Instrument data (id<%s> name<%s>) has already been assigned to model (id<%s> name<%s>)%s.',
                $existing_ida->instrument_data_id,
                $existing_ida->run_name,
                $self->model->id,
                $self->model->name,
                (
                    $existing_ida->filter_desc 
                    ? ' with filter ' . $existing_ida->filter_desc
                    : ''
                )
            )
        );
        return 1;
    }

    my $ida = Genome::Model::InstrumentDataAssignment->create(
        model_id => $self->model->id,
        instrument_data_id => $instrument_data->id,
        filter_desc => $self->filter,
        #first_build_id  => undef,  # set when we run the first build with this instrument data
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
            'Instrument data (id<%s> name<%s>) assigned to model (id<%s> name<%s>)%s.',
            $instrument_data->id,
            $instrument_data->run_name,
            $self->model->id,
            $self->model->name,
            (
                $ida->filter_desc 
                ? (' with filter ' . $ida->filter_desc)
                : ''
            )
        )
    );

    return 1;
}

sub _get_instrument_data_for_id {
    my ($self, $id) = @_;

    my $instrument_data = Genome::InstrumentData->get($id);
    unless ( $instrument_data ) {
        $self->error_message( 
            sprintf('Failed to find specified instrument data for id (%s)', $id) 
        );
        return;
    }

    return $instrument_data;
}

#< Methods Run Based on Inputs >#
sub _assign_by_instrument_data_id {
    my $self = shift;

    # Get it 
    my $instrument_data = $self->_get_instrument_data_for_id( $self->instrument_data_id );

    # Check subject
    unless ($self->force()) {
        
        my $model = $self->model();
        
        if ($model->subject_type() eq 'library_name') {
            unless ($self->_check_instrument_data_library($instrument_data)) {
                return;
            }
        }
        elsif ($model->subject_type() eq 'sample_name') {
            unless ($self->_check_instrument_data_sample($instrument_data)) {
                return;
            }
        }
        
    }
    
    # Assign it
    return $self->_assign_instrument_data($instrument_data)
}

sub _assign_by_instrument_data_ids {
    my $self = shift;

    # Get the ids
    my @ids = split(/\s+/, $self->instrument_data_ids);
    unless ( @ids ) {
        $self->error_message("No instrument data ids found in instrument_data_id input: ".$self->instrument_data_id);
        return;
    }

    # Get the instrument data
    my @instrument_data;
    for my $id ( @ids ) {
        unless ( push @instrument_data, Genome::InstrumentData->get($id) ) {
            $self->error_message( 
                sprintf('Failed to find specified instrument data for id (%s)', $id) 
            );
            return;
        }
    }

    # Assign 'em
    for my $instrument_data ( @instrument_data ) {
        unless ($self->force()) {   
            my $model = $self->model();
            if ($model->subject_type() eq 'library_name') {
                unless ($self->_check_instrument_data_library($instrument_data)) {
                    return;
                }
            }
            elsif ($model->subject_type() eq 'sample_name') {
                unless ($self->_check_instrument_data_sample($instrument_data)) {
                    return;
                }
            }   
        }
        $self->_assign_instrument_data($instrument_data)
            or return;
    }

    return 1;
}

sub _assign_all_instrument_data {
    my $self = shift;

    # Assign all unassigned if requested 
    $self->status_message("Attempting to assign all available instrument data");

    my @unassigned_instrument_data = $self->model->unassigned_instrument_data;

    unless ( @unassigned_instrument_data ){
        $self->error_message("Attempted to assign all instrument data that was unassigned for model, but found none");
        return;
    }

    my @inputs = Genome::Model::Input->get(model_id => $self->model_id(), name => 'target_region_set_name');

    my %model_capture_targets = map { $_->value_id() => 1 } @inputs;

    ID: for my $id ( @unassigned_instrument_data ) {

        my $id_capture_target;

        if ($id->can('target_region_set_name')) {
            $id_capture_target = $id->target_region_set_name();
        }

        if (defined($id_capture_target)) {

            unless (exists($model_capture_targets{$id_capture_target})) {
                $self->warning_message("IGNORING INSTRUMENT DATA: " . $id->id 
                                           . " sequencing platform " . $id->sequencing_platform
                                               . ".\nThe model and instrument data's capture targets do not match, and you've requestied that only matching capture data should be added.\n"
                                                   ."Assign the instrument data explicitly if you want it in the model."
                                               );
                next ID;
            }
        }

        if ($id->isa("Genome::InstrumentData::Imported")) {
            $self->warning_message("IGNORING IMPORTED INSTRUMENT DATA: " . $id->id 
                . " sequencing platform " . $id->sequencing_platform
                . " imported by " . $id->user_name
                . ".  Add this explicitly if you want it in the model."
            );
            next ID;
        }

        $self->_assign_instrument_data($id)
            or return;
    }

    return 1;
}

sub _list_compatible_instrument_data {
    my $self = shift;

    my @compatible_instrument_data = $self->model->compatible_instrument_data;
    my @assigned_instrument_data   = $self->model->assigned_instrument_data;
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

# This logic probably really belongs somewhere else,
# maybe up in the model?
#
# RT #58368
sub _check_instrument_data_library {

    my $self            = shift;
    my $instrument_data = shift;
    
    my $model              = $self->model();
    my $model_subject_name = $self->model->subject_name();

    if ($model->subject_id() ne $instrument_data->library_id()) {
            
        my $id_library_name = $instrument_data->library_name();
        
        my $msg = "Mismatch between instrument data library ($id_library_name) ".
                  "and model subject ($model_subject_name), " .
                  "use --force to assign anyway";

        $self->error_message($msg);
        
        return 0;
        
    }

    return 1;
    
}

sub _check_instrument_data_sample {

    my $self            = shift;
    my $instrument_data = shift;
    
    my $model              = $self->model();
    my $model_subject_name = $self->model->subject_name();
    
    if ($model->subject_id() ne $instrument_data->sample_id()) {
        
        my $id_sample_name = $instrument_data->sample_name();

        my $msg = "Mismatch between instrument data sample ($id_sample_name) ".
                  "and model subject ($model_subject_name), " .
                  "use --force to assign anyway";

        $self->error_message($msg);

        return 0;
        
    }

    return 1;
    
}

1;

#$HeadURL$
#$Id$
