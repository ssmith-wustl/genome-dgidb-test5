package Genome::Model::Command::Define::Helper;

use strict;
use warnings;

use Genome;
use File::Path;
use Carp 'confess';

class Genome::Model::Command::Define::Helper {
    is => 'Command::V2',
    is_abstract => 1,
    has => [
        processing_profile => {
            is => 'Genome::ProcessingProfile',
            id_by => 'processing_profile_id',
            doc => 'Processing profile to be used by model, can provide either a name or an id',
        },
        processing_profile_name => {
            is => 'Text',
            via => 'processing_profile',
            to => 'name',
        },
    ],
    has_optional => [
        subject => {
            is => 'Genome::Subject',
            id_by => 'subject_id',
            doc => 'Subject for the model, can provide either a name or an id. If instrument data is provided and this is not, ' .
                'an attempt will be made to resolve it based on the provided instrument data'
        },
        subject_name => {
            is => 'Text',
            via => 'subject',
            to => 'name',
            doc => 'The name of the subject of the model',
        },
        model_name => {
            is => 'Text',
            doc => 'User meaningful name for this model, a default is used if none is provided',
        },
        auto_assign_inst_data => {
            is => 'Boolean',
            default_value => 0,
            doc => 'Assigning instrument data to the model is performed automatically',
        },
        auto_build_alignments => {
            is => 'Boolean',
            default_value => 1,
            doc => 'The building of the model is performed automatically',
        },
        result_model_id => {
            is => 'Number',
            is_transient => 1,
            doc => 'Stores the ID of the newly created model, useful when running this command from a script',
        },
    ],
    has_many_optional => [
        instrument_data => {
            is => 'Genome::InstrumentData',
            doc => 'Instrument data to be assigned to the model, can provide a query to resolve, a list of ids, etc'
        },
        groups => {
            is => 'Genome::ModelGroup',
            doc => 'Model groups to put the newly created model into',
        },        
        bare_args => {
            shell_args_position => 99
        },
    ],
};

sub help_brief {
    my $self = shift;
    my $msg;
    my $processing_profile_subclass = eval {$self->_target_class_name };
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
        $self->error_message("extra arguments: @args");
        $self->usage_message($self->help_usage_complete_text);
        return;
    }

    my $processing_profile = $self->validate_processing_profile;
    unless ($processing_profile) {
        confess "Could not validate processing profile!";
    }

    unless ($self->subject) {
        my $subject = $self->deduce_subject_from_instrument_data;
        unless ($subject) {
            confess "Not given subject and could not derive subject from instrument data!";
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
        model_groups => [$self->groups],
        $self->type_specific_parameters_for_create,
    );
    unless ($model) {
        confess "Could not create a model!";
    }

    $self->result_model_id($model->id);
    $self->display_model_information($model);
    return 1;
}

sub deduce_subject_from_instrument_data {
    my $self = shift;

    my @instrument_data = $self->instrument_data;
    unless (@instrument_data) {
        confess "No instrument data provided, cannot deduce subject!";
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

    # TODO Could possibly create a population group here similar to convergence models instead of failing
    confess "Could not deduce model subject from provided instrument data!";
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
    unless ($self->compare_pp_and_model_type) {
        confess 'Model and processing profile types do not match!';
    }
    return 1;
}

# TODO This may not be necessary. Even if it is, there's probably a better way to do it.
sub compare_pp_and_model_type {
    my $self = shift;

    # Determine the subclass of model being defined
    my $model_subclass = $self->class;
    my $package = "Genome::Model::Command::Define::";
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

