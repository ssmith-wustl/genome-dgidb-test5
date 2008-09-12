
# IN DEVELOPMENT

package GroupQueuedSequenceAnalysisOutput;

use strict;
use warnings;
use Genome;

class GroupQueuedSequenceAnalysisOutput {
    is => 'Command',
    has =>[ ],
};


sub execute {
    my $self = shift;


    my $queue_ps = GSC::ProcessStep->get(process_to => 'queue sequence analysis output');
    
    my $build_ps = GSC::ProcessStep->get(process_to => 'build sequence analysis genome model');
    
    my $transfer_pattern_bridge = GSC::ProcessStepTransferPattern->get(ps_id => $build_ps->id);

    my @queue_pses = GSC::PSE->get(ps_id => $queue_ps->id, pse_status=>'inprogress');
    
    return 1 unless @queue_pses;

    my %model_hash;

    for my $queue_pse (@queue_pses){

        my $key = $queue_pse->model_id_string;
        push @{$model_hash{$key}}, $queue_pse->id;
    }

    my %params;
    for my $key (keys %model_hash){
      

        $params{control_pse_id} = $model_hash{$key};
        $params{tp_id} = $transfer_pattern_bridge->tp_id;


        my $pse = $build_ps->execute(%params);
        unless ($pse){
            $self->error_message("Couldn't execute pse for $key");
            die;
        }

=cut
        my $pse = $build_ps->schedule(%params);

        unless ($pse){
            $self->error_message("couldn't schedule a build sequence analysis genome model pse for $key")
        }

        $pse; #TODO go
=cut
        
    }

    return 1;
}
1;

