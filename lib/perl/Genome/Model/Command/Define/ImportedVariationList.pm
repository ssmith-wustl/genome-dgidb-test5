package Genome::Model::Command::Define::ImportedVariationList;

use strict;
use warnings;

use Data::Dumper;
use Genome;

my $pp_name = "imported-variation-list";

class Genome::Model::Command::Define::ImportedVariationList {
    is => ['Genome::Model::Command::Define', 'Genome::Command::Base'],
    has_input => [
        version => {
            is => 'Text',
            doc => 'The version of the build to create or update',
        },
        snv_feature_list => {
            is_optional => 1,
            is => 'Genome::FeatureList',
            doc => 'The FeatureList containing imported SNVs',
        },
        indel_feature_list => {
            is_optional => 1,
            is => 'Genome::FeatureList',
            doc => 'The FeatureList containing imported indels',
        },
        prefix => {
            is_optional => 1,
            is => 'Text',
            doc => 'The prefix for the name of the model to create or update (no spaces)',
        },
        model_name => {
            is_optional => 1,
            is => 'Text',
            doc => 'Override the default model name ({prefix}-{reference sequence model} by default)',
        },
        subject_name => {
            is_optional => 1,
            is_optional => 1,
            doc => 'Copied from reference.'
        },
    ],
    has_optional => [
        job_dispatch => {
            default_value => 'inline',
            doc => 'dispatch specification: an LSF queue or "inline"',
        },
        server_dispatch => {
            default_value => 'inline',
            doc => 'dispatch specification: an LSF queue or "inline"',
        },
        _reference => {
            is => 'Genome::Model::Build::ImportedReferenceSequence',
        }
    ],
};

sub resolve_class_and_params_for_argv {
    my $self = shift;
    return $self->Genome::Command::Base::resolve_class_and_params_for_argv(@_);
}

sub _shell_args_property_meta {
    my $self = shift;
    return $self->Genome::Command::Base::_shell_args_property_meta(@_);
}

sub help_synopsis {
    return "genome model define imported-variation-list --model-name=dbSNP-human --version=130 --feature-list='dbSNP 130 hs37 bed'";
}

sub help_detail {
    return "Creates an imported variation list build (defining a new model if needed).";
}

# if the function returns true, then we got satisfactory input for snv/indel feature list(s)
# and $self->_reference is set to the proper reference sequence
sub _validate_feature_lists_and_reference {
    my $self = shift;

    my @flists;
    my %refs_hash;
    for my $type ("snv", "indel") {
        my $var = "${type}_feature_list";
        next if (!defined $self->$var);
        if (ref($self->$var) ne 'Genome::FeatureList') {
            $self->error_message("$var='".$self->$var."' is not a valid FeatureList object.");
            return;
        }

        my $dname = $self->$var->__display_name__;
        if (!defined $self->$var->reference) {
            $self->error_message("$var='".$dname."' does not specify a reference sequence, which is required for ImportedVariationList");
            return;
        }

        push @flists, $self->$var;
        $refs_hash{$self->$var->reference} = 1;
    }

    if (@flists == 0) {
        $self->error_message("Please specify at least one of --snv-feature-list, --indel-feature-list");
        return;
    }

    if (keys %refs_hash != 1) {
        $self->error_message("The feature lists specified contain different reference sequences: " . join(",", keys %refs_hash));
        return;
    }

    $self->_reference($flists[0]->reference);
    return 1;
}

# copy subject_{name,id,class_name,type} from $self->_reference
sub _copy_subject_properties_from_refmodel {
    my $self = shift;
    my $refmodel = $self->_reference->model;
    for my $subj_prop ('name', 'id', 'class_name', 'type') {
        my $p = "subject_$subj_prop";
        $self->$p($refmodel->$p);
        $self->status_message("Copied $p '" . $self->$p . "' from reference");
    }
}

sub execute {
    my $self = shift;

    unless(defined($self->prefix) || defined($self->model_name)) {
        $self->error_message("Please specify one of 'prefix' or 'model_name'");
        return;
    }

    if (defined($self->prefix) and ($self->prefix eq '' or $self->prefix =~ / /)) {
        $self->error_message("Invalid value for prefix '" . $self->prefix . "'. Please specify a non-empty string containing no spaces.");
        return;
    }

    # make sure we got at least one of --snv-feature-list, --indel-feature-list and 
    # verify that reference sequences are defined and match
    return unless $self->_validate_feature_lists_and_reference;

    # set subject_* properties 
    $self->_copy_subject_properties_from_refmodel();

    my $model = $self->_get_or_create_model();
    unless ($model) {
        $self->error_message("Failed to get or create model.");
        return;
    }
    $self->result_model_id($model->id);

    return $self->_create_build($model);
}

sub _check_existing_builds {
    my ($self, $model) = @_;

    if($model->type_name ne 'imported variation list') {
        $self->error_message("A model with the name '" . $self->model_name . "' already exists, but it is not an imported variation list.");
        return;
    }

    if ($model->reference->id != $self->_reference->id) {
        $self->error_message("Existing model '" . $model->__display_name__ . "' has reference sequence " . $model->reference->__display_name__ .
            " which conflicts with specified value of " . $self->_reference->__display_name);
        return;
    }

    my @builds = Genome::Model::Build::ImportedVariationList->get(model_id => $model->id, version => $self->version);
    if (scalar(@builds) > 0) {
        my $plural = scalar(@builds) > 1 ? 's' : ''; 
        $self->error_message("Existing build$plural of this model found: " . join(', ', map{$_->__display_name__} @builds));
        return;
    }

    $self->status_message('Using existing model of name "' . $model->name . '" and id ' . $model->genome_model_id . '.');

    return $model;
}

sub _get_or_create_model {
    my $self = shift;

    # * Generate a model name if one was not provided
    unless(defined($self->model_name)) {
        $self->model_name($self->prefix . "-" . $self->_reference->name);
        $self->status_message('Generated model name "' . $self->model_name . '".');
    }

    # * Make a model if one with the appropriate name does not exist.  If one does, check whether making a build for it would duplicate an
    #   existing build.
    my @models = Genome::Model->get('name' => $self->model_name);
    my $model;

    if(scalar(@models) > 1) {
        $self->error_message("More than one model (" . scalar(@models) . ") found with the name \"" . $self->model_name . "\".");
        return;
    } elsif(scalar(@models) == 1) {
        # * We're going to want a new build for an existing model, but first we should see if there are already any builds
        #   of the same version for the existing model.  If so, we ask the user to confirm that they really want to make another.
        $model = $self->_check_existing_builds($models[0]);
    } else {
        # * We need a new model
        
        my $ivl_pp = Genome::ProcessingProfile->get(name=>$pp_name);
        unless($ivl_pp){
            $self->error_message("Could not locate ImportedVariationList ProcessingProfile by name \"$pp_name\"");
            die $self->error_message;
        }

        my %create_params = (
            name => $self->model_name,
            reference => $self->_reference,
            subject_name => $self->subject_name,
            subject_class_name => $self->subject_class_name,
            subject_id => $self->subject_id,
            processing_profile_id => $ivl_pp->id,
        );

        $model = Genome::Model::ImportedVariationList->create(%create_params);

        if($model) {
            if(my @problems = $model->__errors__){
                $self->error_message( "Error creating model:\n\t".  join("\n\t", map({$_->desc} @problems)) );
                return;
            } else {
                $self->status_message('Created model of name "' . $model->name . '" and id ' . $model->genome_model_id . '.');
            }
        } else {
            $self->error_message("Failed to create a new model.");
            return;
        }
    }

    return $model;
}

sub _create_build {
    my $self = shift;
    my $model = shift;

    my %build_parameters = (
        model_id => $model->id,
        version => $self->version,
    );
    $build_parameters{snv_feature_list} = $self->snv_feature_list if $self->snv_feature_list;
    $build_parameters{indel_feature_list} = $self->indel_feature_list if $self->indel_feature_list;

    my $build = Genome::Model::Build::ImportedVariationList->create(%build_parameters);
    if($build) {
        $self->status_message('Created build of id ' . $build->build_id . ' with data directory "' . $build->data_directory . '".');
    } else {
        $self->error_message("Failed to create build for model " . $model->genome_model_id . ".");
        return;
    }

    my @dispatch_parameters;
    if(defined($self->server_dispatch)) {
        push @dispatch_parameters,
            server_dispatch => $self->server_dispatch;
    }

    if(defined($self->job_dispatch)) {
        push @dispatch_parameters,
            job_dispatch => $self->job_dispatch;
    }

    $self->status_message('Starting build.');
    if($build->start(@dispatch_parameters)) {
        $self->status_message('Started build (build is complete if it was run inline).');
    } else {
        $self->error_message("Failed to start build " . $build->build_id . " for model " . $model->genome_model_id . ".");
        return;
    }

    return 1;
}

1;

