# FIXME ebelter
# Long: remove all define modules to just have one to rule them all.
# Short: There are 2 if blocks that should have errors in them? This module builds? It shouldn't.
#
package Genome::Model::Command::Define::GenotypeMicroarray;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Define::GenotypeMicroarray {
    is => [
        'Genome::Model::Command::Define',
        'Genome::Command::Base',
        ],

    has => [
        file => {
            is => 'Path',
            is_input => 1,
            doc => 'path to the file or directory of microarray data',
        },
        reference => {
            is => 'Genome::Model::Build::ImportedReferenceSequence',
            is_input => 1,
            doc => 'reference sequence build for this model',
        },
        no_build => {
            is => 'Boolean',
            is_optional => 1,
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
    return <<"EOS"
genome model define genotype-microarray 
  --subject-name MY_SAMPLE
  --processing-profile-name illumina/wugc
  --reference g1k-human-build37
  --file /my/snps
EOS
}

sub help_detail {
    return <<"EOS"
Define a new genome model with genotype information based on microarray data.
EOS
}

sub type_specific_parameters_for_create {
    my $self = shift;
    return (reference_sequence_build => $self->reference);
}

sub execute {
    my $self = shift;
    my $file = $self->file;

    # This only needs to be done b/c we're not tracking microarray data as instrument data.
    # Once it _is_ tracked as instrument data, the normal model/build process would occur.

    $DB::single = 1;

    unless ($file and -s $file) {
        $self->error_message("Provided genotype file: $file is not valid.");
        return;
    }
    
    #step to validate input genotype snp file is 9-column like followings:
    #1       554484  554484  C       C       ref     ref     ref     ref
    my $head    = `head -1 $file`;
    my @columns = split /\s+/, $head;
    
    unless (@columns and @columns == 9) {
        $self->error_message("Genotype file: $file is not 9-column format");
        return;
    }
    
    # let the super class make the model
    my $super = $self->super_can('_execute_body');
    $super->($self,@_);
    unless ($self->result_model_id) {
        $self->error_message("Failed to define a new model: " . $self->error_message);
        return;
    }

    my $model = Genome::Model->get($self->result_model_id);
    unless ($model) {
        $self->error_message("Failed to find new model : " . $self->result_model_id);
        return;
    }

    # TODO: we should flag model types which do not do multiple builds and which should auto build when defined.
    # For now this is just handled in the command which does the model definition.

    unless ($self->no_build) {

        $self->status_message("building...\n");
        my $cmd = Genome::Model::Build::Command::Start->execute(models => [$model]);
        unless ($cmd) {
            $self->error_message("Failed to run a build on model " . $model->id . ": " . Genome::Model::Build::Command::Start->error_message);
            return;
        }

        my ($build) = $cmd->builds;
        unless ($build) {
            $self->error_message("Failed to generate a new build for model " . $model->id . ": " . $cmd->error_message);
            return;
        }

        $self->status_message("Copying genotype data to " . $build->formatted_genotype_file_path . "...");
        Genome::Sys->copy_file(
            $file,
            $build->formatted_genotype_file_path
        );

    }

    return $self;
}

1;

