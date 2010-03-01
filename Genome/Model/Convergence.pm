package Genome::Model::Convergence;

use strict;
use warnings;

use Genome;

class Genome::Model::Convergence {
    is  => 'Genome::Model',
    has => [
        group_id => {
            is => 'Integer',
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'group', value_class_name => 'Genome::ModelGroup' ],
            doc => 'The id for the ModelGroup for which this is the Convergence model',
            
            is_mutable => 1,
        },
        group => {
            is => 'Genome::ModelGroup',
            id_by => 'group_id',
            doc => 'The ModelGroup for which this is the Convergence model',
        },
        members => {
            is => 'Genome::Model',
            via => 'group',
            is_many => 1,
            to => 'models',
            doc => 'Models that are members of this Convergence model.',
        },
        map({
            $_ => {
                via => 'processing_profile',
            }
        } Genome::ProcessingProfile::Convergence->params_for_class),
    ],
    doc => <<EODOC
This model type attempts to use the data collected across many samples to generalize and summarize
knowledge about the group as a whole.
EODOC
};


sub launch_rebuild {
    my $self = shift;
    
    unless($self->auto_build_alignments){
        $self->status_message('auto_build_alignments is false for this convergence model');
        return 1;
    }
    
    unless (scalar grep(defined $_->last_succeeded_build, $self->members)) {
        $self->status_message('Skipping convergence rebuild--no succeeded builds found.');
        return 1;
    }
    
    my $build_command = Genome::Model::Build::Command::Start->create(
        model_identifier => $self->id,
        force => 1,
    );

    unless ($build_command->execute == 1) {
        $self->error_message("Genome::Model::Command::Build::Start Execute failed launching convergence rebuild. " . $build_command->error_message);
        return;
    }
    
    return 1;
}

1;
