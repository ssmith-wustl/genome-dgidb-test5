package Genome::Model::Command::Define::GenePrediction;

use strict;
use warnings;

use Genome;
use Carp;

class Genome::Model::Command::Define::GenePrediction {
    is => 'Genome::Model::Command::Define',
    has_optional => [
        start_assembly_build => {
            is => 'Boolean',
            default => 0,
            doc => 'If set, an assembly build is started if a completed build is not found on the assembly model',
        },
        create_assembly_model => {
            is => 'Boolean',
            default => 0,
            doc => 'If set, an assembly model is created if one cannot be found with the supplied taxon',
        },
        assembly_processing_profile_name => {
            is => 'Number',
            default => 'Velvet Solexa BWA Qual 10 Filter Length 35',
            doc => 'The processing profile used to create assembly models, if necessary',
        },
        subject_name => {
            is => 'Text',
            doc => 'The name of the subject all the reads originate from',
        },
        assembly_model_id => {
            is => 'Number',
            doc => 'ID for the assembly model this gene prediction model should link to',
        },
        assembly_model => { 
            is => 'Genome::Model',
            id_by => 'assembly_model_id', 
            doc => 'imported assembly model to get assembly from',
        },
        taxon_id => {
            is => 'Number',
            doc => 'ID of taxon to be used, this can be derived from the assembly model',
        },
        taxon => {
            is => 'Genome::Taxon',
            id_by => 'taxon_id',
            doc => 'Taxon that will be used as the subject of this model',
        },
        dev => {
            is => 'Boolean',
            default => 0,
            doc => 'If set, use dev databases instead of production databases',
        },
        run_type => {
            is => 'String',
            default => 'DFT',
            doc => 'A three letter identifier appended to the locus ID',
        },
        assembly_version => {
            is => 'String',
            default => 'Version_1.0',
            doc => 'Notes the assembly version',
        },
        project_type => {
            is => 'String',
            default => 'HGMI',
            doc => 'The type of project this data is being generated for',
        },
        pipeline_version => {
            is => 'String',
            default => 'Version_1.0',
            doc => 'Notes the pipeline version',
        },
        acedb_version => {
            is => 'String',
            default => 'Version_5.0',
            doc => 'Notes the version of aceDB to upload results to',
        },
        nr_database_location => {
            is => 'String',
            default => '/gscmnt/gpfstest2/analysis/blast_db/gsc_bacterial/bacterial_nr/bacterial_nr',
            doc => 'Default location of the NR database, may be overridden with a local copy if specified',
        },
        use_local_nr => {
            is => 'Boolean',
            default => 0,
            doc => 'If set, local NR databases are used by blast jobs instead of accessing ' .
                   'the default location over the network',
        },
    ],
};

sub help_synopsis {
    return <<"EOS"
genome model define 
  --processing-profile-name "blah"
  --assembly-model 54321
EOS
}

sub help_detail {
    return <<"EOS"
There are lots of ways to define a gene prediction model. A processing profile name is always
required. Beyond that, if given just a taxon ID, this command looks for DeNovoAssembly and
ImportedAssembly models that have that taxon as their subject. The most recent model is 
used, with DeNovoAssembly models taking precedence over ImportedAssembly. If no model is
found, then a model is either created for the user if the --create-assembly-model flag is
set, otherwise the necessary commands are printed for the user.

If given an assembly model ID, get that model and get its taxon. If given both an assembly
model and a taxon ID, get the model and make sure that its taxon matches the supplied one.

Once an assembly model has been found and selected, look for a successful build. If one is not
found, kick off a build if the --start-assembly-build option is set. If that option is not set, 
output the commands the user would have to execute to get a build started.

With a successful assembly build, all the information needed to create the new gene prediction
model is available. Once the model is created, set up model links so all further builds of the
assembly model will kick off a build of this gene prediction model. 
EOS
}

sub execute {
    my $self = shift;

    # Need to find an assembly model that has this taxon as its subject. If one can't be found, then
    # either make one and assign instrument data to it (if the --create-assembly-model flag is set) 
    # or tell the user how to do it
    if (defined $self->taxon and not defined $self->assembly_model) {
        my @denovo = Genome::Model::DeNovoAssembly->get(
            subject_name => $self->taxon->name,
            subject_class_name => 'Genome::Taxon',
        );
        my @imported = Genome::Model::ImportedAssembly->get(
            subject_name => $self->taxon->name,
            subject_class_name => 'Genome::Taxon',
        );
    
        my $assembly_model;
        if (@denovo) {
            $assembly_model = $self->get_most_recent_model(\@denovo);
        }
        elsif (@imported) {
            $assembly_model = $self->get_most_recent_model(\@imported);
        }
        else {
            if ($self->create_assembly_model) {
                $self->status_message("Create assembly model flag is set, creating a new assembly model " .
                    "using processing profile with name " . $self->assembly_processing_profile_name);

                my $assembly_define_obj = Genome::Model::Command::Define::DeNovoAssembly->create(
                    processing_profile_name => $self->assembly_processing_profile_name,
                    subject_name => $self->taxon->name,
                );
                unless ($assembly_define_obj) {
                    $self->error_message("Could not create assembly model define object!");
                    croak;
                }

                my $define_rv = $assembly_define_obj->execute;
                unless (defined $define_rv and $define_rv == 1) {
                    $self->error_message("Trouble while attempting to define new assembly model!");
                    croak;
                }

                my $model_id = $assembly_define_obj->result_model_id;
                $assembly_model = Genome::Model::DeNovoAssembly->get($model_id);
                unless ($assembly_model) {
                    $self->error_message("Could not get newly created assembly model with ID $model_id!");
                    croak;
                }

                $self->status_message("Successfully created assembly model with ID $model_id, now assigning data!");

                my $assembly_assign_obj = Genome::Model::Command::InstrumentData::Assign->create(
                    model_id => $model_id,
                    all => 1,
                );
                unless ($assembly_assign_obj) {
                    $self->error_message("Could not create instrument data assignment object!");
                    croak;
                }

                my $assign_rv = $assembly_assign_obj->execute;
                unless (defined $assign_rv and $assign_rv == 1) {
                    $self->error_message("Trouble while attempting to assign instrument data to model!");
                    croak;
                }

                $self->status_message("Instrument data has been successfully assigned to model!");
            }
            else {
                $self->status_message(
                    "Could not find any assembly models with the taxon you provided. If you would like to create an " .
                    "assembly model for use with this gene prediction model, run the following command\n" .
                    "genome model define de-novo-assembly --processing-profile-name " . $self->assembly_processing_profile_name . 
                    " --subject-name " . $self->taxon->name . "\n\n" .
                    "That command should give you a model ID. Use it to assign instrument data to the assembly model:\n" .
                    "genome instrument-data assign --model-id <MODEL_ID> --all\n\n" .
                    "Now you have an assembly model with instrument data! Rerun this define command with the " .
                    "--assemble option, which will start a build of that assembly model and kick off gene prediction " .
                    "once that build has completed!"
                );
                die "Could not find any assemblies for taxon " . $self->taxon_id;
            }
        }

        $self->assembly_model_id($assembly_model->genome_model_id);
        $self->assembly_model($assembly_model);
    }
    # Sorry, can't do any magic without a minimum amount of given information
    elsif (not defined $self->taxon and not defined $self->assembly_model) {
        $self->error_message("Must be supplied with an assembly model ID and/or a taxon ID!");
        croak;
    }

    # Alright, if we've reached this point we have an assembly model (though it may not have a successful build)
    # First, get that model's taxon and, if this command was given a taxon ID, compare. If the given taxon does not
    # match the one on the assembly model, emit an error message and exit since its not clear if the model ID
    # or the taxon ID is in error.
    my $taxon = $self->assembly_model->subject;
    unless ($taxon->isa('Genome::Taxon')) {
        $self->error_message("Assembly model does not have a taxon as its subject!");
        croak;
    }
    
    if (defined $self->taxon_id and $self->taxon_id ne $taxon->id) {
        $self->error_message("Given taxon " . $self->taxon_id . " does not match taxon " . $taxon->id . " on assembly model!");
        croak;
    }
    else {
        $self->taxon_id($taxon->id);
        $self->taxon($taxon);
    }

    # Now check for a successful build of the assembly model. If one does not exist, kick off a build if the --assemble
    # flag has been set, otherwise tell the user how to kick off a build and exit.
    my $build = $self->assembly_model->last_succeeded_build;
    $build = $self->assembly_model->current_running_build unless $build;
    unless ($build) {
        $self->warning_message("No successful or running build of assembly model " . $self->assembly_model_id . " found!");

        if ($self->assemble) {
            $self->status_message("Assemble flag is set! Starting a build of the assembly model!");
            my $start_command = Genome::Model::Build::Command::Start->create(
                model_identifier => $self->assembly_model_id,
            );
            unless ($start_command) {
                $self->error_message("Could not create the build start command object!");
                croak;
            }

            my $rv = $start_command->execute;
            unless (defined $rv and $rv == 1) {
                $self->error_message("Could not start build of assembly model!");
                croak;
            }

            $self->status_message("Started build " . $start_command->build->id . "!");
        }
        else {
            $self->status_message(
                "The assemble option is not set, so automatic build of the assembly model will not occur. " .
                "Either rerun this command with the --assemble flag or manually kick off a build by running:\n" .
                "genome model build start --model " . $self->assembly_model_id);
            die "No assembly build found and assemble flag not set";
        }
    }

    # Now create the gene prediction model!
    my $rv = $self->SUPER::_execute_body(@_);
    unless ($rv) {
        $self->error_message("Could not create new gene prediction model!");
        return;
    }

    my $model = Genome::Model->get($self->result_model_id);
    unless ($model) {
        $self->error_message("Could not get newly created gene prediction model with ID " . $self->result_model_id);
        croak;
    }

    # Make a link from the assembly model to this model and vice versa. This link will be used to kick off a new build
    # of the gene prediction model every time its linked assembly model completes a build.
    my $to_rv = $self->assembly_model->add_to_model(
        to_model => $model,
        role => 'gene_prediction_model',
    );
    my $from_rv = $model->add_from_model(
        from_model => $self->assembly_model,
        role => 'assembly_model',
    );
    unless ($to_rv and $from_rv) {
        $self->error_message("Could not create a link from the assembly model to the gene prediction model! Cannot create model!");
        croak;
    }

    # Add inputs to the model
    $model->add_input(
        value_class_name => 'UR::Value',
        value_id => $self->get_contigs_file($build),
        name => 'contigs_file_location',
    );
    $model->add_input(
        value_class_name => 'UR::Value',
        value_id => $self->dev,
        name => 'dev',
    );
    $model->add_input(
        value_class_name => 'UR::Value',
        value_id => $self->run_type,
        name => 'run_type',
    );
    $model->add_input(
        value_class_name => 'UR::Value',
        value_id => $self->assembly_version,
        name => 'assembly_version',
    );
    $model->add_input(
        value_class_name => 'UR::Value',
        value_id => $self->project_type,
        name => 'project_type',
    );
    $model->add_input(
        value_class_name => 'UR::Value',
        value_id => $self->pipeline_version,
        name => 'pipeline_version',
    );
    $model->add_input(
        value_class_name => 'UR::Value',
        value_id => $self->acedb_version,
        name => 'acedb_version',
    );
    $model->add_input(
        value_class_name => 'UR::Value',
        value_id => $self->nr_database_location,
        name => 'nr_database_location',
    );
    $model->add_input(
        value_class_name => 'UR::Value',
        value_id => $self->use_local_nr,
        name => 'use_local_nr',
    );

    return 1;
}

# Calculates the path to the contigs file within the assembly build directory,
# check that the file is there, and returns the path
sub get_contigs_file {
    my ($self, $assembly_build) = @_;
    my $path = $assembly_build->data_directory . "/edit_dir/contigs.bases";
    unless (-e $path) {
        $self->warning_message("Could not find contigs.bases file at $path!");
        return;
    }
    return $path;
}

# Given a list of models, return the most recent. This is determined using the model ID,
# which is assumed to be larger for new models.
sub get_most_recent_model {
    my ($self, $assembly_models) = @_;
    my @sorted_models = sort {$b->genome_model_id <=> $a->genome_model_id} @$assembly_models;
    return shift @sorted_models;
}

1;
