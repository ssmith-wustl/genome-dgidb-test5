#FIXME ebelter
# Long: Stop sub classing, handle iniput defining
#
package Genome::Model::Command::Define;

use strict;
use warnings;

use Genome;
use Carp 'confess';
use File::Path;
use Data::Dumper;
require Genome::Sys;

my @subject_types = ();
{
    my $gm_class = Genome::Model->__meta__;
    my $m = $gm_class->property_meta_for_name('subject_type');
    @subject_types = @{ $m->valid_values };
}

###################################################

class Genome::Model::Command::Define {
    is => 'Command::DynamicSubCommands',
    is_abstract => 1,
    has => [
        subject_name => {
            is => 'Text',
            len => 255,
            is_input => 1,
            doc => 'The name of the subject all the reads originate from'
        },
    ],
    has_optional => [
        model_name => {
            is => 'Text',
            len => 255,
            is_input => 1,
            doc => 'User meaningful name for this model (default value: $SUBJECT_NAME.$PP_NAME)'
        },
        processing_profile_name => {
            is => 'Text', 
            is_input => 1,
            doc => 'identifies the processing profile by name' 
        },
        processing_profile_id => {
            is => 'Integer',
            is_input => 1,
            doc => 'identifies the processing profile by id'
        },
        data_directory => {
            is => 'Text',
            len => 255,
            is_input => 1,
            doc => 'Optional parameter representing the data directory the model should use. Will use a default if none specified.'
        },
        subject_type => {
            is => 'Text',
            len => 255,
            is_input => 1,
            doc => 'The type of subject all the reads originate from (sample_name is assumed if none given)',
            valid_values => \@subject_types
        },
        subject_id => {
            is => 'Number',
            len => 15,
            is_input => 1,
            doc => 'The ID of the subject all the reads originate from (may specify this and subject_class_name in lieu of subject_type)',  
        },
        subject_class_name => {
            is => 'Text',
            len => 500,
            is_input => 1,
            doc => 'The Perl class name of the subject whose ID is subject_id'  
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
            is => 'Integer',
            is_output => 1,
        },
        bare_args => {
            is_many => 1,
            is_optional => 1,
            shell_args_position => 99
        },
        groups => {
            is_optional => 1,
            doc => 'Model group(s) to which this model will be assigned upon creation. Provide a comma separated list of model group id\'s or names.',
        },
    ],
    schema_name => 'Main',
};

# Compiling this class autogenerates one sub-command per processing profile.
# These are the commands which actually execute, and inherit from this
# for general execution logic.

sub _sub_commands_from { 'Genome::ProcessingProfile' }

sub sub_command_sort_position { 1 }

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
  --subject-name ley_aml_patient1_tumor
  --processing-profile-name nature_aml_08
EOS
}

sub help_detail {
    return <<"EOS"
This defines a new genome model for the specified subject, using the 
specified processing profile.

The first build of a model must be explicitly requested after the model is defined.
EOS
}

sub execute {
    my $self = shift;

    # Make sure there aren't any bare args
    if (my @args = $self->bare_args) {
        $self->error_message("extra arguments: @args");
        $self->usage_message($self->help_usage_complete_text);
        return;
    }

    if (defined($self->processing_profile_name)) {
        my @pp = Genome::ProcessingProfile->get(name => $self->processing_profile_name);
        if (@pp > 1){
            $self->error_message("ProcessingProfile name returned multiple processing profiles.");
            return;
        }
        my $pp = $pp[0];
        unless($pp){
            $self->error_message("The processing profile name ".$self->processing_profile_name." was not found.");
            return;
        }
        # If both name and id are provided, make sure they agree
        if (defined($self->processing_profile_id)) {
            unless ($pp->id == $self->processing_profile_id) {
                $self->error_message("The provided processing profile name " . $self->processing_profile_name . " and processing profile id " . $self->processing_profile_id . " do not match.");
                return;
            }
        } else {
            $self->processing_profile_id($pp->id);
        }
    } elsif (defined($self->processing_profile_id)){
        my @pp = Genome::ProcessingProfile->get(id => $self->processing_profile_id);
        unless(@pp==1){
            $self->error_message("ProcessingProfile id returned multiple processing profiles.");
            return;
        }
        my $pp = $pp[0];
        unless($pp){
            $self->error_message("The processing profile id ".$self->processing_profile_id." was not found.");
            return;
        }
        $self->processing_profile_name($pp->name);
    }

    $self->compare_pp_and_model_type;

    #attempt derive subject_type if not passed as an arg
    #die if subject type isnt sample_name for now
    my ($subject_type, $subject_id, $subject_class_name);
    if ($self->subject_id and $self->subject_class_name) {
        $subject_class_name = $self->subject_class_name;
        $subject_id = $self->subject_id;
        
        my $subject = $subject_class_name->get($subject_id);
        
        unless($subject) {
            $self->error_message('Subject not found for subject with id ' . $subject_id . ' and class ' . $subject_class_name);
            return;
        }
    }
            
    # Create the model
    my %model_params = (
        name => $self->model_name,
        processing_profile_id => $self->processing_profile_id,
        subject_name => $self->subject_name,
        subject_type => $self->subject_type,
        subject_id => $subject_id,
        subject_class_name => $subject_class_name,
        auto_assign_inst_data => $self->auto_assign_inst_data,
        auto_build_alignments => $self->auto_build_alignments,
        $self->type_specific_parameters_for_create,
    );
    if(defined($self->subject_class_name)&&defined($self->subject_name)){
        if($self->subject_class_name eq "Genome::Sample"){
            my $sample = Genome::Sample->get(name=>$self->subject_name);
            unless( $sample ){
                $self->error_message("Subject was a Genome::Sample, but no Genome::Sample named ".$self->subject_name." could be retrieved.");
                die $self->error_message;
            }
            $model_params{sample_name}= $self->subject_name;
        }elsif($self->subject_class_name eq "Genome::Library"){
            my $library = Genome::Library->get(name=>$self->subject_name);
            unless($library){
                $self->error_message("Subject is a library, however the library named ".$self->subject_name." cannot be found.");
                die $self->error_message;
            }
            my $sample = Genome::Sample->get(name => $library->sample_name);
            unless($sample){
                $self->error_message("The sample named ".$library->sample_name." associated with the subject/library could not be found.");
                die $self->error_message;
            }
            $model_params{sample_name}=$sample->name;
        }
    }
    if ($self->data_directory) {
        my $model_name = File::Basename::basename($self->data_directory);
        unless ($model_name eq $self->model_name) {
            my $new_data_directory = $self->data_directory .'/'. $self->model_name;
            $self->data_directory($new_data_directory);
        }
        $model_params{data_directory} = $self->data_directory;
    }

    my $model = Genome::Model->create(%model_params);
    unless ( $model ) {
        $self->error_message('Could not create a model for: '. $self->subject_name);
        return;
    }

    if ( my @problems = $model->__errors__ ) {
        $self->error_message(
            "Error creating model:\n\t".  join("\n\t", map { $_->desc } @problems)
        );
        $model->delete;
        return;
    }

    # Add the model to any model groups requested
    if ($self->groups) {
        my @groups = split ",", $self->groups;
        for my $model_group_id (@groups) {
            # Try to get model group by name or id, allow a negative ID due to test cases
            my $model_group;
            if ($model_group_id =~ /^-?\d+$/) {
                $model_group = Genome::ModelGroup->get($model_group_id);
            } else {
                $model_group = Genome::ModelGroup->get(name => $model_group_id);
            }
            unless ($model_group) {
                $self->error_message("Could not find a model group with the id or name of: $model_group. Please use a valid id/name or create a model-group.");
                die;
            }
            $model_group->assign_models($model);
        }
    }

    $self->status_message("Created model:");
    my $list = Genome::Model::Command::List->create(
        filter => 'id='.$model->id,
        show => join(
            ',', 
            ($self->listed_params),
            #$model->processing_profile->params_for_class,
        ),
        style => 'pretty',
    );
    $list->execute;
    $self->result_model_id($model->id);

    return 1;
}

sub listed_params {
    return qw/ id name data_directory subject_name subject_type processing_profile_id processing_profile_name /;
}

sub type_specific_parameters_for_create {
    my $self = shift;

    return (); #This exists to be overwritten by subclasses
}

sub compare_pp_and_model_type {
    my $self = shift;

    # Determine the subclass of model being defined
    my $model_subclass = $self->class;
    my $package = __PACKAGE__ . "::";
    $model_subclass =~ s/$package//;
    
    # Determine the subclass of the processing profile
    my $pp = Genome::ProcessingProfile->get(id=>$self->processing_profile_id);
    unless($pp){
        $self->error_message("Couldn't find the processing profile identified by the #: ".$self->processing_profile_id);
        die $self->error_message;
    }
    my $pp_subclass = $pp->subclass_name;
    $pp_subclass =~ s/Genome::ProcessingProfile:://;
    

    #check for special cases where processing-profile-name and model subclass have different names
    if ($model_subclass =~ /GenotypeMicroarray/) {
        unless($pp->name =~ /wugc/){
            $self->error_message("GenotypeMicroarray Models must use one of the [microarray-type]/wugc processing-profiles.");
            die $self->error_message;
        }
        return 1;
    }

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

#$HeadURL$
#$Id$
