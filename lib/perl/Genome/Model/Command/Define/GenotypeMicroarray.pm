# FIXME ebelter
# Long: remove all define modules to just have one to rule them all.
# Short: There are 2 if blocks that should have errors in them? This module builds? It shouldn't.
#
package Genome::Model::Command::Define::GenotypeMicroarray;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';

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
  --reference GRCh37-lite-build37
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
    # This command takes a snp array (ne gold), creates a genotype microarray model and build
    #  and copies the file to the build. This happens because microarray data was not tracked 
    #  as instrument data. This is being changed. The LIMS/AIMS PSE bridge is now handling 
    #  genotype microarray data. Consult rlong or tabbott before significantly 
    my $self = shift;

    my $file = $self->_validate_snp_array_file;
    return if not $file;
   
    # let the super class make the model
    my $super = $self->super_can('_execute_body');
    $super->($self);
    unless ( $self->result_model_id ) {
        $self->error_message("Failed to define a new model: " . $self->error_message);
        return;
    }

    my $model = Genome::Model->get($self->result_model_id);
    unless ($model) {
        $self->error_message("Failed to find new model: " . $self->result_model_id);
        return;
    }

    my $build = $self->_create_and_run_build($model);
    return if not $build;

    my $copy = $build->copy_snp_array_file($file);
    return if not $copy;

    return 1;
}

sub _validate_snp_array_file {
    my $self = shift;

    my $file = $self->file;
    $self->status_message("Validate SNP file: $file");
    if ( not $file or not -s $file ) {
        $self->error_message("Provided genotype file: $file is not valid.");
        return;
    }

    #step to validate input genotype snp file is 9-column like followings:
    #1       554484  554484  C       C       ref     ref     ref     ref
    my $head    = `head -1 $file`;
    my @columns = split /\s+/, $head;
    if ( not @columns or @columns != 9 ) {
        $self->error_message("Genotype file: $file is not 9-column format");
        return;
    }

    $self->status_message("Validate SNP file...OK");

    return $file;
}

sub _create_and_run_build {
    my ($self, $model) = @_;

    $self->status_message("Run build");
    my $build = Genome::Model::Build::GenotypeMicroarray->create(
        model => $model,
    );
    if ( not $build ) {
        $self->error_message('Failed to create build for model '.$model->__display_name__);
        return;
    }

    my $start = $build->start(server_dispatch => 'inline', job_dispatch => 'inline');
    if ( not $start ) {
        $self->error_message('Failed to start build '.$build->__display_name__);
        return;
    }
    $self->status_message("Run build...OK");

    return $build;
}

1;

