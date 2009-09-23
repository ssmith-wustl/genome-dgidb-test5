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

class Genome::Model::Command::Define {
    is => 'Command',
    is_abstract => 1,
    has => [
        processing_profile_name => {
            is => 'Integer', 
            is_optional => 0,
            is_input => 1,
            doc => 'identifies the processing profile by name' 
        },
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
            doc => 'The type of subject all the reads originate from',
            valid_values => \@subject_types
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
	}
    ],
    schema_name => 'Main',
};

sub sub_command_sort_position { 1 }

###################################################

#< Auto generate the subclasses >#
our @SUB_COMMAND_CLASSES;
my $module = __PACKAGE__;
$module =~ s/::/\//g;
$module .= '.pm';
my $pp_path = $INC{$module};
$pp_path =~ s/$module//;
$pp_path .= 'Genome/Model';
for my $target ( glob("$pp_path/*pm") ) {
    $target =~ s#$pp_path/##;
    $target =~ s/\.pm//;
    my $target_class = 'Genome::Model::' . $target;
    next unless $target_class->isa('Genome::Model');
    my $target_meta = $target_class->get_class_object;
    unless ( $target_meta ) {
        eval("use $target_class;");
        die "$@\n" if $@;
        $target_meta = $target_class->get_class_object;
    }
    next if $target_class->get_class_object->is_abstract;
    my $subclass = 'Genome::Model::Command::Define::' . $target;
    #print Dumper({mod=>$module, path=>$pp_path, target=>$target, target_class=>$target_class,subclass=>$subclass});

    # Do not autogenerate this if it is an exception (things with actual modules for define)
    my @targets_to_skip = ("Somatic","GenotypeMicroarray");
    unless (grep {$target eq $_} @targets_to_skip) {
        no strict 'refs';
        class {$subclass} {
            is => __PACKAGE__,
            sub_classification_method_name => 'class',
        };
    }

    push @SUB_COMMAND_CLASSES, $subclass;
}

###################################################

sub sub_command_dirs {
    my $class = ref($_[0]) || $_[0];
    return ( $class eq __PACKAGE__ ? 1 : 0 );
}

sub sub_command_classes {
    my $class = ref($_[0]) || $_[0];
    return ( $class eq __PACKAGE__ ? @SUB_COMMAND_CLASSES : 0 );
}

sub help_brief {
    my $model_type = $_[0]->_model_type;
    $model_type =~ s/genome model command define //;
    my $msg = ($model_type ? "$model_type genome model" : "genome model");
    $msg = "define a new $msg"; 
    return $msg;
}

sub help_synopsis {
    return <<"EOS"
genome model define 
  --model-name test5
  --subject_name ley_aml_patient1_tumor
  --processing-profile-name nature_aml_08
EOS
}

sub help_detail {
    return <<"EOS"
This defines a new genome model.
The properties of the model determine what will happen when the add-reads command is run.

Define the processing profile to be used by name. Do not specify the
processing_profile_id as this will be looked up and overridden by the processing
profile name.

To obtain a list of available processing profiles, use genome-model list
processing-profiles.
EOS
}

###################################################

sub _get_subclass {
    my $class = ref($_[0]) || $_[0];

    return if $class eq __PACKAGE__;
    
    $class =~ s/Genome::Model::Command::Create:://;

    return $class;
}

sub _target_class {
    my $subclass = _get_subclass(@_)
        or return;
    
    return 'Genome::'.$subclass;
}

sub _model_type {
    my $profile_name = _get_subclass(@_)
        or return;
    my @words = $profile_name =~ /([A-Z](?:[A-Z]*(?=$|[A-Z][a-z])|[a-z]*))/g;
    return $profile_name = join(' ', map { lc } @words);
}

###################################################

sub execute {
    my $self = shift;

    # Make sure there aren't any bare args
    my $ref = $self->bare_args;
    if ( $ref && (my @args = @$ref) ) {
        $self->error_message("extra arguments: @args");
        $self->usage_message($self->help_usage_complete_text);
        return;
    }

    # Get processing profile id for the name given
    my $processing_profile_id = $self->_get_processing_profile_id_for_name
        or return;

    #attempt derive subject_type if not passed as an arg
    #die if subject type isnt sample_name for now
    my $subject_type;
    if  ($self->subject_type){
        $subject_type = $self->subject_type;
        }
    else {
        my $sample = Genome::Sample->get(name => $self->subject_name);
        if ($sample){
            $subject_type = 'sample_name'; 
        }
        else {
            $self->status_message('subject_name did not specify a sample, other subject types not yet supported.'); 
            $self->status_message('specify a sample or contact apipe@genome.wustl.edu for creation of a custom model');
        exit;
        }
    }

    # Create the model
    my %model_params = (
        name => $self->model_name,
        processing_profile_id => $processing_profile_id,
        subject_name => $self->subject_name,
        subject_type => $subject_type,
        auto_assign_inst_data => $self->auto_assign_inst_data,
        auto_build_alignments => $self->auto_build_alignments,
    );
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

    $self->status_message("Created model:");
    my $list = Genome::Model::Command::List->create(
        style => 'pretty',
        filter => 'id='.$model->id,
        show => join(
            ',', 
            (qw/ id name data_directory subject_name subject_type processing_profile_id processing_profile_name /),
            #$model->processing_profile->params_for_class,
        ),
    );
    $list->execute;
    $self->result_model_id($model->id);

    return 1;
}

#< Processing profile ># 
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
