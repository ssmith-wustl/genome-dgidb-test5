package Genome::Model::Command::Define::GenePrediction;

use strict;
use warnings;

use Genome;
use Carp;

class Genome::Model::Command::Define::GenePrediction {
    is => 'Genome::Model::Command::Define',
    has_optional => [
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
        contigs_file_location => {
            is => 'Path',
            doc => 'Path to the contigs file, can be derived from the assembly model',
        },
        taxon_id => {
            is => 'Number',
            doc => 'ID of taxon to be used, this can be derived from the assembly model',
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
            default => 1,
            doc => 'If set, local NR databases are used by blast jobs instead of accessing the default location over the network',
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
This defines a new genome model representing gene prediction.
EOS
}

sub execute {
    my $self = shift;

    # Gene prediction models require two things: the contigs file from the assembly and a Genome::Taxon object
    # These can either be derived from a supplied DeNovoAssembly model, or explicitly given
    
    if (defined $self->assembly_model) {
        # Grab taxon from assembly model and set it as this model's subject
        my $taxon = $self->assembly_model->subject;
        unless ($taxon->isa('Genome::Taxon')) {
            $self->error_message("Subject of assembly model not a Genome::Taxon object as expected!");
            croak;
        }
        $self->subject_id($taxon->id);
        $self->subject_class_name('Genome::Taxon');

        # Determine the path to the contigs file... requires a successful build of the assembly model
        my $build = $self->assembly_model->last_succeeded_build;
        unless ($build) {
            $self->error_message("Could not find successful build of assembly model " . $self->assembly_model_id);
            croak;
        }

        if ($build->can('contigs_bases_file')) {
            my $file = $build->contigs_bases_file;
            unless (-e $file) {
                $self->error_message("No file found at $file!");
                croak;
            }
            $self->contigs_file_location($file);
        }
        else {
            $self->error_message("Could not determine contigs.bases file location from assembly model!");
            croak;
        }
    }
    elsif (defined $self->contigs_file_location and $self->taxon_id) {
        unless (-e $self->contigs_file_location) {
            $self->error_message("No file found at " . $self->contigs_file_location);
            croak;
        }

        my $taxon = Genome::Taxon->get($self->taxon_id);
        unless ($taxon) {
            $self->error_message("Could not get taxon object with ID " . $self->taxon_id);
            croak;
        }

        $self->subject_id($self->taxon_id);
        $self->subject_class_name('Genome::Taxon');
    }
    else {
        $self->error_message("Must provide either an assembly model ID or a taxon ID and a contigs file path!");
        croak;
    }

    my $rv = $self->SUPER::_execute_body(@_);
    unless ($rv) {
        $self->error_message("Could not create new gene prediction model!");
        return;
    }

    my $model = Genome::Model->get($self->result_model_id);

    # Add inputs to the model
    $model->add_input(
        value_class_name => 'UR::Value',
        value_id => $self->contigs_file_location,
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

1;
