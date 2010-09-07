#FIXME ebelter
# Long: Stop sub classing, handle iniput defining
#
package Genome::Model::Command::Define;

use strict;
use warnings;

use Genome;
use File::Path;
use Data::Dumper;
require Genome::Utility::FileSystem;

my @subject_types = ();
{
    my $gm_class = Genome::Model->get_class_object;
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
            doc => 'itentifies the processing profile by id'
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
    unless((defined($self->processing_profile_name) && (not defined($self->processing_profile_id)))||
                (not defined($self->processing_profile_name) && defined($self->processing_profile_id))){
        $self->error_message("Must specify either processing profile name or processing profile id.");
        return;
    }
    
    if(defined($self->processing_profile_name)){
        my @pp = Genome::ProcessingProfile->get(name => $self->processing_profile_name);
        unless(@pp==1){
            $self->error_message("ProcessingProfile name returned multiple processing profiles.");
            return;
        }
        my $pp = $pp[0];
        unless($pp){
            $self->error_message("The processing profile name ".$self->processing_profile_name." was not found.");
            return;
        }
        $self->processing_profile_id($pp->id);
    }
    if(defined($self->processing_profile_id)){
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

    # Get processing profile id for the name given
    #my $processing_profile_id = $self->_get_processing_profile_id_for_name
    #    or return;

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
            print Data::Dumper::Dumper $model_group_id;
            unless ($model_group) {
                $self->error_message("Could not find a model group with the id or name of: $model_group. Please use a valid id/name or create a model-group.");
                die;
            }

            my $add_command = Genome::ModelGroup::Command::Member::Add->create(
                  model_group_id => $model_group->id,
                  model_ids => ($model->id),
            );
            unless ($add_command->execute == 1) {
                $self->error_message("Failed to add model to model group $model_group");
                die;
            }
        }
    }

    $self->status_message("Created model:");
    my $list = Genome::Model::Command::List->create(
        filter => 'id='.$model->id,
        show => join(
            ',', 
            (qw/ id name data_directory subject_name subject_type processing_profile_id processing_profile_name /),
            #$model->processing_profile->params_for_class,
        ),
        style => 'pretty',
    );
    $list->execute;
    $self->result_model_id($model->id);

    return 1;
}

sub type_specific_parameters_for_create {
    my $self = shift;

    return (); #This exists to be overwritten by subclasses
}

sub _get_processing_profile_id_for_name {
    my $self = shift;

    unless ( $self->processing_profile_name ) {
        $self->error_message("No name to get processing profile");
        return;
    }
    
    my (@processing_profiles) = Genome::ProcessingProfile->get(name => $self->processing_profile_name);

    unless ( @processing_profiles ) {
        my $msg;
        if (defined $self->processing_profile_name) {
            $msg = "Failed to find processing profile "
                . $self->processing_profile_name . "!\n"
        }
        else {
            $msg = "No processing profile specified!\n";
        }
        $msg .= "Please select from:\n "
                . join("\n ", 
                        grep { defined $_ and length $_ } 
                        map  { $_->name } 
                        Genome::ProcessingProfile->get() 
                    ) 
                . "\n";
        $self->error_message($msg);
        return;
    }

    # Bomb out unless exactly 1 matching processing profile is found
    unless ( @processing_profiles == 1 ) {
        $self->error_message(
            sprintf('Found multiple processing profiles for name (%s)', $self->processing_profile_name)
        );
        return;
    }

    return $processing_profiles[0]->id;
}


1;

#$HeadURL$
#$Id$
