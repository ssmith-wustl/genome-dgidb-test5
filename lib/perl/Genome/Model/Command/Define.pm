package Genome::Model::Command::Define;

use strict;
use warnings;

use Genome;
use Carp 'confess';
use File::Path;
use Data::Dumper;
require Genome::Sys;

###################################################

class Genome::Model::Command::Define {
    is => 'Command::DynamicTree', 
    is_abstract => 1,
    has => [
        processing_profile => {
            is => 'Genome::ProcessingProfile',
            is_input => 1,
            doc => 'Processing profile to be used by model, can provide either a name or an id',
        },
    ],
    has_optional => [
        subject => {
            is => 'Genome::Subject',
            is_input => 1,
            doc => 'Subject for the model, can provide either a name or an id. If instrument data is provided and this is not, ' .
                'an attempt will be made to resolve it based on the provided instrument data'
        },
        model_name => {
            is => 'Text',
            is_input => 1,
            doc => 'User meaningful name for this model, a default is used if none is provided',
        },
        auto_assign_inst_data => {
            is => 'Boolean',
            default_value => 0,
            is_input => 1,
            doc => 'Assigning instrument data to the model is performed automatically',
        },
        auto_build_alignments => {
            is => 'Boolean',
            default_value => 1,
            is_input => 1,
            doc => 'The building of the model is performed automatically',
        },
        result_model_id => {
            is => 'Number',
            is_output => 1,
            is_transient => 1,
            doc => 'Stores the ID of the newly created model, useful when running this command from a script',
        },
    ],
    has_many_optional => [
        instrument_data => {
            is => 'Genome::InstrumentData',
            is_input => 1,
            doc => 'Instrument data to be assigned to the model, can provide a query to resolve, a list of ids, etc'
        },
        groups => {
            is => 'Genome::ModelGroup',
            is_input => 1,
            doc => 'Model groups to put the newly created model into',
        },
        bare_args => {
            shell_args_position => 99
        },
    ],
};

# Compiling this class autogenerates one sub-command per processing profile.
# These are the commands which actually execute, and inherit from this
# for general execution logic.
sub _sub_commands_from { 'Genome::ProcessingProfile' }

sub help_brief {
    my $self = shift;
    my $msg;
    my $processing_profile_subclass = $self->_target_class_name;
    if ($processing_profile_subclass) {
        my $model_type = $processing_profile_subclass->_resolve_type_name_for_class;
        $msg = "define a new $model_type genome model";
    }
    else {
        $msg = 'define a new genome model'
    }
    return $msg;
}

sub help_synopsis {
    return <<"EOS"
genome model define reference-alignment 
  --model-name test5
  --subject ley_aml_patient1_tumor
  --processing-profile nature_aml_08
EOS
}

sub help_detail {
    return <<"EOS"
This defines a new genome model for the specified subject, using the 
specified processing profile.

The first build of a model must be explicitly requested after the model is defined.
EOS
}

# Should be overridden in subclasses
sub type_specific_parameters_for_create {
    my $self = shift;
    return (); 
}

sub execute {
    my $self = shift;

    if (my @args = $self->bare_args) {
        $self->error_message("Extra arguments: @args");
        $self->usage_message($self->help_usage_complete_text);
        return;
    }

    my $processing_profile = $self->validate_processing_profile;
    unless ($processing_profile) {
        Carp::confess "Could not validate processing profile!";
    }

    unless ($self->subject) {
        my $subject = $self->deduce_subject_from_instrument_data;
        unless ($subject) {
            Carp::confess "Not given subject and could not derive subject from instrument data!";
        }
        $self->subject($subject);
    }
            
    my $model = Genome::Model->create(
        subject_id => $self->subject->id,
        subject_class_name => $self->subject->class,
        processing_profile_id => $self->processing_profile->id,
        name => $self->model_name,
        auto_assign_inst_data => $self->auto_assign_inst_data,
        auto_build_alignments => $self->auto_build_alignments,
        instrument_data => [$self->instrument_data],
        $self->type_specific_parameters_for_create,
    );
    unless ($model) {
        Carp::confess "Could not create a model!";
    }
    $self->result_model_id($model->id);

    unless ($self->assign_model_to_groups($model)) {
        Carp::confess "Encountered problems when trying to assign model to groups!";
    }

    #if (my $rule = $model->create_rule_limiting_instrument_data) {
    #    $model->limit_inputs_to_id($rule);
    #}

    $self->display_model_information($model);
    $self->result_model_id($model->id);

    return 1;
}

sub deduce_subject_from_instrument_data {
    my $self = shift;

    my @instrument_data = $self->instrument_data;
    unless (@instrument_data) {
        Carp::confess "No instrument data provided, cannot deduce subject!";
    }

    my @samples = map { $_->sample } @instrument_data;
    unless (grep { $_->id ne $samples[0]->id } @samples) {
        return $samples[0];
    }

    my @individuals = map { $_->source } @samples;
    unless (grep { $_->id ne $individuals[0]->id } @individuals) {
        return $individuals[0];
    }

    my @taxons = map { $_->taxon } @individuals;
    unless (grep { $_->id ne $taxons[0]->id } @taxons) {
        return $taxons[0];
    }

    Carp::confess "Could not deduce model subject from provided instrument data!";
}

sub assign_model_to_groups {
    my ($self, $model) = @_;
    return 1 unless $self->groups;

    for my $group ($self->groups) {
        my $rv = $group->assign_models($model);
        unless ($rv) {
            Carp::confess "Could not assign model " . $model->__display_name__ . " to group " . $group->__display_name__;
        }
    }

    return 1;
}

sub display_model_information {
    my ($self, $model) = @_;

    $self->status_message("Created model:");
    my $list = Genome::Model::Command::List->create(
        filter => 'id=' . $model->id,
        show => join(',', $self->listed_params),
        style => 'pretty',
    );
    return $list->execute;
}

sub listed_params {
    return qw/ id name subject_name subject_type processing_profile_id processing_profile_name /;
}

sub validate_processing_profile {
    my $self = shift;
    
    unless ($self->processing_profile) {
        Carp::confess 'Could not resolve a processing profile from provided parameters!';
    }

    unless ($self->compare_pp_and_model_type) {
        Carp::confess 'Model and processing profile types do not match!';
    }
    
    return 1;
}

sub compare_pp_and_model_type {
    my $self = shift;

    # Determine the subclass of model being defined
    my $model_subclass = $self->class;
    my $package = __PACKAGE__ . "::";
    $model_subclass =~ s/$package//;
    
    # Determine the subclass of the processing profile
    my $pp = Genome::ProcessingProfile->get(id => $self->processing_profile->id);
    unless($pp){
        $self->error_message("Couldn't find the processing profile identified by the #: " . $self->processing_profile->id);
        die $self->error_message;
    }
    my $pp_subclass = $pp->subclass_name;
    $pp_subclass =~ s/Genome::ProcessingProfile:://;
    
    unless ($model_subclass eq $pp_subclass) {
        my ($shortest, $longest) = ($model_subclass, $pp_subclass);
        ($shortest, $longest) = ($longest, $shortest) if length $pp_subclass < length $model_subclass;
        unless ($longest =~ /$shortest/) {
            $self->error_message("Model subclass $model_subclass and ProcessingProfile subclass $pp_subclass do not match!");
            confess;
        }
    }

    return 1;
}

1;
