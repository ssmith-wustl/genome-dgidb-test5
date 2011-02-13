package Genome::Model::Convergence;

use strict;
use warnings;

use Genome;

use Array::Compare;

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


sub schedule_rebuild {
    my $self = shift;
    
    unless($self->auto_build_alignments){
        $self->status_message('auto_build_alignments is false for this convergence model');
        return 1;
    }
    
    my @potential_members = grep(defined $_->last_complete_build, $self->members); 
    unless(scalar @potential_members) {
        $self->status_message('Skipping convergence rebuild--no succeeded builds found among members.');
        return 1;
    }
    
    #Check to see if our last build already used all the same builds as we're about to
    if($self->last_complete_build) {
        my $last_build = $self->last_complete_build;
        
        my @last_members = $last_build->members;
        
        my $comparator = Array::Compare->new;
        if($comparator->perm(\@last_members, \@potential_members)) {
            $self->status_message('Skipping convergence rebuild--list of members that would be included is identical to last build.');
            return 1;
            
            #Potentially if some of the underlying builds in the $build->all_subbuilds_closure have changed, a rebuild might be desired
            #For now this will require a manual rebuild (`genome model build start`)
        }
    }

    my @builds_to_kill = grep{$_->status eq 'Scheduled' or $_->status eq 'Running'} $self->builds;
    if (scalar(@builds_to_kill)){
        my $rv = Genome::Model::Build::Command::Stop->execute(builds => [@builds_to_kill]);
        $self->warning_message("Failed to remove pending convergence models: " . join(",", map($_->id, @builds_to_kill))) unless $rv; 
    }

    $self->build_requested(1);
    $self->status_message('Convergence rebuild requested.');

    return 1;
}

1;
