# IN DEVELOPMENT

package Genome::Model::Command::BuildPolyphredPolyscanModels;

use strict;
use warnings;
use Genome;

class Genome::Model::Command::BuildPolyphredPolyscanModels{
    is => 'Command',  #TODO, do I need to be an event?
    has =>[ ],
};

sub execute {
    my $self = shift;

    my $queue_ps = GSC::ProcessStep->get(process_to => 'queue instrument data for genome modeling');
    
    my @queue_pses = GSC::PSE->get(ps_id => $queue_ps->id, pse_status=>'inprogress');
    
    return 1 unless @queue_pses;

    my %model_ids;
    for my $pse (@queue_pses){
        my @ids = $pse->added_param('model_id');  
        unless (@ids) { 
            $self->error_message("pse(id:".$pse->id.") did not have any model ids associated with it!");
            die;
        }
        for my $id (@ids){
            $model_ids{$id}++;
        }
    }
    
    my @models;
    foreach my $id (keys %model_ids){
        my $command = Genome::Model::Command::Build::PolyphredPolyscan->create(
            model_id => $id,
            event_type => 'genome-model build polyphred-polyscan', 
        );
        #$command->execute_with_bsub;
        my $model = $command->execute;
        push @models, $model;
    }

    unless (@models == keys(%model_ids)) {
        $self->error_message("Got " . @models . " models but should have " . keys(%model_ids) . " according to PSE's");
    }
        
    return @models;
}
1;
