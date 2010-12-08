package Genome::Model::Command::Define::ImportedVariationList;

use strict;
use warnings;

use Data::Dumper;
use Genome;

my $pp_name = "imported-variation-list";

class Genome::Model::Command::Define::ImportedVariationList {
    is => ['Genome::Model::Command::Define', 'Genome::Command::Base'],
    has => [
        feature_list => {
            is => 'Genome::FeatureList',
            doc => 'The FeatureList containing the imported variation list file',
        },
        version => {
            is => 'Text',
            doc => 'The version of the build to create or update',
        },
    ],
    has_optional => [
        reference => {
            is => 'Genome::Model::ImportedReferenceSequence',
            doc => 'The reference sequence the imported variations apply to. Must be supplied if feature_list does not specify the reference property.',
        }, 
        prefix => {
            is => 'Text',
            doc => 'The prefix for the name of the model to create or update (no spaces)',
        },
        model_name => {
            is => 'Text',
            doc => 'Override the default model name ({prefix}-{reference sequence model} by default)',
        },

        subject_name => {
            is_optional => 1,
            doc => 'Copied from reference.'
        },

        job_dispatch => {
            default_value => 'apipe',
            doc => 'dispatch specification: an LSF queue or "inline"'
        },
        server_dispatch => {
            default_value => 'workflow',
            doc => 'dispatch specification: an LSF queue or "inline"'
        },
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

sub execute {
    my $self = shift;

    if (ref($self->feature_list) ne 'Genome::FeatureList') {
        $self->error_message("Supplied feature list '".$self->feature_list."' is not a valid FeatureList object.");
        return;
    }

    my $fl_ref = $self->feature_list->reference;
    my $ref = $self->reference;
    unless (defined($fl_ref) || defined($ref)) {
        $self->error_message("Feature list '".$self->feature_list->name."' does not specify a reference, and none explicitly provided.");
        return;
    }

    if (defined($fl_ref) and $ref and $fl_ref ne $ref) {
        $self->error_message("Supplied reference sequence '$ref' does not match feature list reference '$fl_ref'");
        return;
    }

    $self->reference($self->reference || $self->feature_list->reference);
    my $refmodel = $self->reference->model;
    for my $subj_prop ('name', 'id', 'class_name', 'type') {
        my $p = "subject_$subj_prop";
        $self->$p($refmodel->$p);
        $self->status_message("Copied $p '" . $self->$p . "' from reference");
    }

    unless(defined($self->prefix) || defined($self->model_name)) {
        $self->error_message("Please specify one of 'prefix' or 'model_name'");
        return;
    }

    if (defined($self->prefix) and ($self->prefix eq '' or $self->prefix =~ / /)) {
        $self->error_message("Invalid value for prefix '" . $self->prefix . "'. Please specify a non-empty string containing no spaces.");
        return;
    }

    $DB::single = 1;
    my $model = $self->_get_or_create_model();
    $DB::single = 1;
    unless ($model) {
        $self->error_message("Failed to get or create model.");
        return;
    }
    $self->result_model_id($model->id);

    return $self->_create_build($model);
}

sub _check_existing_builds {
    my $self = shift;
    my $model = shift;

    if($model->type_name ne 'imported variation list') {
        $self->error_message("A model with the name '" . $self->model_name . "' already exists, but it is not an imported reference sequence.");
        return;
    }

    if ($model->reference->id != $self->reference->id) {
        $self->error_message("Existing model '" . $model->__display_name__ . "' has reference sequence " . $model->reference->__display_name__ .
            " which conflicts with specified value of " . $self->reference->__display_name);
        return;
    }

    print "gettinate builds.\n";
    my @builds = Genome::Model::Build::ImportedVariationList->get(model_id => $model->id, verision => $self->version);
    print "got builds.\n";
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
    my $taxon = shift;

    # * Generate a model name if one was not provided
    unless(defined($self->model_name)) {
        $self->model_name($self->prefix . "-" . $self->reference->name);
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
        $model = $self->_check_existing_builds($models[0], $taxon);
    } else {
        # * We need a new model
        
        my $ivl_pp = Genome::ProcessingProfile->get(name=>$pp_name);
        unless($ivl_pp){
            $self->error_message("Could not locate ImportedVariationList ProcessingProfile by name \"$pp_name\"");
            die $self->error_message;
        }

        $model = Genome::Model::ImportedVariationList->create(
            name => $self->model_name,
            reference => $self->reference,
            subject_name => $self->subject_name,
            subject_class_name => $self->subject_class_name,
            subject_id => $self->subject_id,
            processing_profile_id => $ivl_pp->id,
        );

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
        data_directory => $self->data_directory,
        feature_list => $self->feature_list,
    );

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

