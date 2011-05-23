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
        include_imported => {
            is => 'Boolean',
            default => 0,
            doc => 'Include imported instrument data when assigning all via the --all switch',
        },
        filter => {
            is => 'Text',
            valid_values => ['forward-only','reverse-only'],
        },
        all_within_maximum_allowed_error => {
             is => 'Boolean',
             default => 0,
             doc => 'Assign all available unassigned instrument data within maximum allowed error (default = 3.0) as paired/forward/reverse data.',
        },
        maximum_allowed_error => {
            type => 'Float',
            is_optional => 1,
            doc => "The maximum allowed gerald error rate to assign to a model",
            default => 3.0,
        },
        force => {
            is => 'Boolean',
            default => 0,
            doc => 'Allow assignment of data even if the subject does not match the model',
        },
    ],
};

sub help_brief {
    return "Assign instrument data to a model";
}

sub help_detail {
    return help_brief();
}

#TODO:put this logic in Genome::Model::assign_instrument_data() and turn this command into a thin wrapper
sub execute {
    my $self = shift;

    my @requested_actions = grep { 
        $self->$_ 
    } qw(flow_cell_id instrument_data_id instrument_data_ids all);

    if ( @requested_actions > 1 ) {
        $self->error_message('Multiple actions requested: '.join(', ', @requested_actions));
        return;
    }

    $self->_verify_model
        or  return;

    if ( $self->instrument_data_id ) { # assign this
        return $self->_assign_by_instrument_data_id;
    }
    elsif ( $self->instrument_data_ids ) { # assign these
        return $self->_assign_by_instrument_data_ids;
    }
    elsif ( $self->flow_cell_id ) { #assign all instrument data ids whose sample name matches the models subject name and flow_cell_id matches the flow_cell_id given by the user
        my $flow_cell_id = $self->flow_cell_id;

        my $flow_cell = Genome::InstrumentData::FlowCell->get($flow_cell_id);
        unless($flow_cell) {
            $self->error_message('Flow cell not found: ' . $flow_cell_id);
            return;
        }

        my @instrument_data;
        if($self->force) {
            #Just get all lanes
            @instrument_data = $flow_cell->lanes();
        } else {
            #Subject must match
            my $subject = $self->model->subject;
            unless($subject and $subject->isa('Genome::Sample')) {
                $self->error_message('Adding instrument data by flow cell id is only set up to handle models with samples as subjects. Use --force to add all lanes regardless of sample.');
                return;
            }
            @instrument_data = $flow_cell->lanes(sample_id => $subject->id);
        }

        unless ( scalar @instrument_data ){
            $self->error_message("Found no matching instrument data for flowcell id $flow_cell_id");
            return;
        }

        for my $instrument_data (@instrument_data) {
            unless($self->_assign_instrument_data($instrument_data)) {
                return;
            }
        }
        return 1;
    }
    elsif ( $self->all_within_maximum_allowed_error ) {
        return $self->_assign_all_within_maximum_allowed_error;
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
    my $model = $self->model;
    if ( grep { $instrument_data->id eq $_->id } $model->instrument_data ) {
        $self->status_message(
            sprintf(
                'Instrument data (%s) already assigned to model (%s). Skipping.',
                $instrument_data->id,
                $model->__display_name__,
            )
        );
        return 1;
    }

    my $add = $model->add_instrument_data(
        value => $instrument_data,
        filter_desc => $self->filter,
    );
    if ( not $add ) {
        $self->error_message(
            sprintf(
                'Failed to add instrument data (%s) to model (%s).',
                $instrument_data->id,
                $model->__display_name__,
            )
        );
        return;
    }

    $self->status_message(
        sprintf(
            'Instrument data (%s) assigned to model (%s)%s.',
            $instrument_data->id,
            $model->__display_name__,
            ( $self->filter ? (' with filter ' . $self->filter) : '')
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

sub _assign_all_within_maximum_allowed_error {
    my $self = shift;

    $self->status_message("Attempting to assign all available instrument data within maximum allowed error of " . $self->maximum_allowed_error . ".");

    my $model = $self->model;
    my $instdata_iterator = Genome::InstrumentData->create_iterator(
        where => [ id => [ map { $_->id } $self->model->unassigned_instrument_data ] ],
    );

    # add as all if fwderr is null. Assuming fragment run if this is the case
    my (@allin, @reverse, @forward);
    while (my $instdata = $instdata_iterator->next) {
        my $instdata_id = $instdata->id;
        my $flowcell    = $instdata->flow_cell_id;
        my $lane        = $instdata->subset_name;
        my $libname     = $instdata->library_name;
        my $reverr      = $instdata->filt_error_rate_avg; #this is intentionally not rev_filt_error_rate_avg
        my $fwderr      = $instdata->fwd_filt_error_rate_avg;
        if($instdata->ignored() ) {
            next;
        }
        if(($reverr < $self->maximum_allowed_error) && (!$fwderr || ($fwderr < $self->maximum_allowed_error))) {
            push(@allin, $instdata_id);
        }
        elsif($reverr < $self->maximum_allowed_error) {
            push(@reverse, $instdata_id);
            $self->status_message("Excluding forward read of $flowcell lane $lane with id $instdata_id due to error rate of $fwderr%"); 
        }
        elsif($fwderr && $fwderr < $self->maximum_allowed_error) {
            push(@forward, $instdata_id);
            $self->status_message("Excluding reverse read of $flowcell lane $lane with id $instdata_id due to error rate of $reverr%"); 
        }
        else {
            my $error_report_string = !$fwderr ? "($reverr%)" : "($fwderr%, $reverr%)";
            $self->status_message("Excluding $flowcell lane $lane with id $instdata_id due to error rate $error_report_string");
        }
    }

    #report how many lanes of each type were found
    $self->status_message(sprintf("%d all good\n",scalar(@allin)));
    $self->status_message(sprintf("%d forward only\n",scalar(@forward)));
    $self->status_message(sprintf("%d reverse only\n",scalar(@reverse)));

    for my $allin ( @allin ) {
        my $add = $model->add_instrument_data(
            value => $allin,
        );
        if ( not $add ) {
            $self->error_message('Failed to add instrument data ('.$allin->id.') to model '.$model->__display_name__);
        }
    }
    for my $fwd ( @forward ) {
        my $add = $model->add_instrument_data(
            value => $fwd,
            filter => 'forward-only',
        );
        if ( not $add ) {
            $self->error_message('Failed to add instrument data ('.$fwd->id.') to model '.$model->__display_name__);
        }
    }
    for my $rev ( @reverse ) {
        my $add = $model->add_instrument_data(
            value => $rev,
            filter => 'reverse-only',
        );
        if ( not $add ) {
            $self->error_message('Failed to add instrument data ('.$rev->id.') to model '.$model->__display_name__);
        }
    }
    return 1;
}

sub _assign_all_instrument_data {
    my $self = shift;

    # Assign all unassigned if requested 
    $self->status_message("Attempting to assign all available instrument data");

    my @unassigned_instrument_data = $self->model->unassigned_instrument_data;

    unless ( @unassigned_instrument_data ){
        $self->status_message("No unassigned instrument data for model");
        return 1;
    }

    my @inputs = Genome::Model::Input->get(model_id => $self->model_id(), name => 'target_region_set_name');

    my %model_capture_targets = map { $_->value_id() => 1 } @inputs;

    ID: for my $id ( @unassigned_instrument_data ) {

        if($id->ignored() ){
            next ID;
        }

        # Skip imported, w/ warning
        unless($self->include_imported){
            if ($id->isa("Genome::InstrumentData::Imported")) {
                $self->warning_message(
                    'SKIPPING instrument data ('.join(' ', map { $id->$_ } (qw/ id sequencing_platform user_name /)).' because '
                    .'it is imported. Assign it explicitly, if desired.'
                );
                next ID;
            }
        }

        # Get inst data region set name
        my $id_capture_target;
        eval { 
            $id_capture_target = $id->target_region_set_name;
        };

        # Skip if no mpdel_capture targets and the inst data has a target
        if( not %model_capture_targets and defined $id_capture_target) {
            $self->warning_message(
                'SKIPPING instrument data ('.$id->id.' '.$id->sequencing_platform.') because '
                .' it does not have a capture target and the model does. Assign it explicitly, if desired.'
            );
            next ID;
        }

        # Skip if the model has capture targets and the inst data's target is undef OR 
        #  is not in the list of the model's targets
        if ( %model_capture_targets 
                and ( not defined $id_capture_target or not exists $model_capture_targets{$id_capture_target} ) ) {
            $self->warning_message(
                'SKIPPING instrument data ('.$id->id.' '.$id->sequencing_platform.') because '
                .' the model\'s and instrument data\'s capture targets do not match. Assign it explicitly, if desired.' 
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
    my @assigned_instrument_data   = $self->model->instrument_data;
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
