package Genome::Model::Command::Build::CombineVariants::RunDetectEvaluate::SingleAssembly;

use warnings;
use strict; 
use Genome;

class Genome::Model::Command::Build::CombineVariants::RunDetectEvaluate::SingleAssembly {
    is => 'Command',
    has => [
        assembly_name => { 
            is => 'String', 
            doc => 'Assembly to run' 
        },
        assembly_directory => { 
            is => 'String', 
            doc => 'Assembly project directory' 
        },
    ],
};

sub help_brief {
    "Kicks off the 3730 pipeline by creating 'detect sequence variation' and 'evaluate sequence variation' PSEs for a single assembly name.",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
gt combine-variants run-detect-evaluate single-assembly --assembly-names one,two,three --project-dir /some/dir --output-dir /some/dir ...
EOS
}

sub help_detail {
    return <<EOS
EOS
}

sub execute {
    my $self = shift;

    my $asp_name = $self->assembly_name;
    my $assembly_directory = $self->assembly_directory;
    unless (-d $assembly_directory) {
        $self->error_message("Assembly directory $assembly_directory does not exist");
        return;
    }

    my (@detect_seq_var_pses, $new_pse);
    my $asp = GSC::AssemblyProject->get(assembly_project_name => $asp_name);
    unless ($asp) {
        $self->error_message("Could not get assembly project for assembly name $asp_name");
        return;
    }

    # This bare query is used because it is much faster than any alternative
    my $update_mp_assembly_query = q/
    select tp.pse_id from tpp_pse tp
    where tp.prior_pse_id in(
    select api.pse_id from assembly_project_item@dw api
    join assembly_project@dw ap on ap.asp_id = api.asp_id
    where ap.assembly_project_name =  ? and rownum =1)/;
    my $sth = GSC::TppPSE->dbh->prepare($update_mp_assembly_query);
    $sth->execute($asp_name);
    my $ref = $sth->fetchall_arrayref;

    unless ($ref and @$ref) {
        $self->error_message("Could not get update mp assembly pse");
        return;
    }
    my $control_pse_id = $ref->[0]->[0];

    my $setup = GSC::Setup::SequenceAnalysis->get(setup_name => 'Default Detect and Evaluate Sequence Variation');
    unless ($setup) {
        $self->error_message("Could not get setup");
        return;
    }
    
    my $ds = GSC::DirectedSetup->get(setup_id => $setup->id);
    unless ($ds) {
        $self->error_message("Could not get directed setup");
        return;
    }

    my $ids = GSC::InheritedDirectedSetup->get(pse_id=> $control_pse_id , ds_id => $ds->id);
    unless ($ids){
        $ids = GSC::InheritedDirectedSetup->create(pse_id=> $control_pse_id , ds_id => $ds->id);
    }
    unless ($ids) {
        $self->error_message("Could not get or create inherited directed setup");
        return;
    }

    my $detect_ps = GSC::ProcessStep->get(process_to => 'detect sequence variation');

    my $tp = GSC::ProcessStepTransferPattern->get(ps_id => $detect_ps->id);
    unless ($tp) {
        $self->error_message("Could not get process step transfer pattern");
        return;
    }

    # Build a hash for pse params to pass in
    my $pse_params;
    $pse_params->{transfer_pattern} = $tp;
    $pse_params->{control_pse_id} = $control_pse_id;
    $pse_params->{assembly_project} = $asp;

    ###########################################################################
    #Detect Sequence Variation
    #polyphred s 1 10##########################################################
    my $pps = GSC::ProcessParamSet->get(ps_id => $detect_ps->id, pps_name => 'polyphred s 1 10');
    unless ($pps) {
        $self->error_message("Failed to get process param set");
        return;
    }
    $pse_params->{process_param_set} = $pps;

    $new_pse = $self->run_detect_pse($detect_ps, $pse_params);
    unless($new_pse) {
        $self->error_message("Failed to create pse in run_detect_pse");
        return;
    }
    push @detect_seq_var_pses, $new_pse;
    
    #polyphred s 1 25##########################################################
    $pps = GSC::ProcessParamSet->get(ps_id => $detect_ps->id, pps_name => 'polyphred s 1 25');
    unless ($pps) {
        $self->error_message("Failed to get process param set");
        return;
    }
    $pse_params->{process_param_set} = $pps;

    $new_pse = $self->run_detect_pse($detect_ps, $pse_params);
    unless($new_pse) {
        $self->error_message("Failed to create pse in run_detect_pse");
        return;
    }
    push @detect_seq_var_pses, $new_pse;
 
    #polyscan s 1 10##########################################################
    $pps = GSC::ProcessParamSet->get(ps_id => $detect_ps->id, pps_name => 'polyscan s 1 10');
    unless ($pps) {
        $self->error_message("Failed to get process param set");
        return;
    }
    $pse_params->{process_param_set} = $pps;

    $new_pse = $self->run_detect_pse($detect_ps, $pse_params);
    unless($new_pse) {
        $self->error_message("Failed to create pse in run_detect_pse");
        return;
    }
    push @detect_seq_var_pses, $new_pse;

    #polyscan s 1 25##########################################################
    $pps = GSC::ProcessParamSet->get(ps_id => $detect_ps->id, pps_name => 'polyscan s 1 25');
    unless ($pps) {
        $self->error_message("Failed to get process param set");
        return;
    }
    $pse_params->{process_param_set} = $pps;

    $new_pse = $self->run_detect_pse($detect_ps, $pse_params);
    unless($new_pse) {
        $self->error_message("Failed to create pse in run_detect_pse");
        return;
    }
    push @detect_seq_var_pses, $new_pse;


    ###########################################################################
    #Evaluate Sequence Variation
    #POLYSCAN EVALUATIVE s 1 10
    my $evaluate_ps = GSC::ProcessStep->get(process_to => 'evaluate sequence variation');
    $pse_params->{detect_pses} = @detect_seq_var_pses;

    $pps = GSC::ProcessParamSet->get(ps_id => $evaluate_ps->id, pps_name => 'polyscan s 1 10');
    unless ($pps) {
        $self->error_message("Failed to get process param set");
        return;
    }
    $pse_params->{process_param_set} = $pps;

    $new_pse = $self->run_evaluate_pse($evaluate_ps, $pse_params);
    unless($new_pse) {
        $self->error_message("Failed to create pse in run_detect_pse");
        return;
    }

    #####################################
    #POLYSCAN EVALUATIVE s 1 25 
    $pps = GSC::ProcessParamSet->get(ps_id => $evaluate_ps->id, pps_name => 'polyscan s 1 25');
    unless ($pps) {
        $self->error_message("Failed to get process param set");
        return;
    }
    $pse_params->{process_param_set} = $pps;

    $new_pse = $self->run_evaluate_pse($evaluate_ps, $pse_params);
    unless($new_pse) {
        $self->error_message("Failed to create pse in run_detect_pse");
        return;
    }
    
    ################################################################################
    #POLYPHRED ForceGenotype s 1 10
    $pps = GSC::ProcessParamSet->get(ps_id => $evaluate_ps->id, pps_name => 'polyphred s 1 10');
    unless ($pps) {
        $self->error_message("Failed to get process param set");
        return;
    }
    $pse_params->{process_param_set} = $pps;

    $new_pse = $self->run_evaluate_pse($evaluate_ps, $pse_params);
    unless($new_pse) {
        $self->error_message("Failed to create pse in run_detect_pse");
        return;
    }

    ################################################################################
    #POLYPHRED ForceGenotype s 1 25 
    $pps = GSC::ProcessParamSet->get(ps_id => $evaluate_ps->id, pps_name => 'polyphred s 1 25');
    unless ($pps) {
        $self->error_message("Failed to get process param set");
        return;
    }
    $pse_params->{process_param_set} = $pps;

    $new_pse = $self->run_evaluate_pse($evaluate_ps, $pse_params);
    unless($new_pse) {
        $self->error_message("Failed to create pse in run_detect_pse");
        return;
    }

    return 1;
}

sub run_detect_pse {
    my $self = shift;
    my $ps = shift; 
    my $pse_params = shift;

    my $pse = $ps->init_pse;

    $pse->add_param_tp_id($pse_params->{transfer_pattern}->tp_id);
    $pse->add_param(control_pse_id => $pse_params->{control_pse_id});
    $pse->add_param(asp_id => $pse_params->{assembly_project}->asp_id);
    $pse->add_param(project_dir => $self->assembly_directory);
    $pse->add_param(pps_id => $pse_params->{process_param_set}->id);
    $pse->confirmable;
    $pse->confirm;

    my $bridge = GSC::Sequence::AnalysisOutputPSE->get(pse_id => $pse->id);
    unless ($bridge) {
        $self->error_message("Could not get analysis_output_pse");
        return;
    }

    my $file = $pse->output_file_name;
    my $out_obj = $pse->get_output_file_object($file);
    unless (ref $out_obj) {
        $self->error_message("Could not get the output file object");
        return;
    }
    
    return $pse;
}

sub run_evaluate_pse {
    my $self = shift;
    my $ps = shift;
    my $pse_params = shift;

    my $pse = $ps->init_pse;

    $pse->add_param_tp_id($pse_params->{transfer_pattern}->tp_id);
    $pse->add_param(control_pse_id => [map{$_->id} $pse_params->{detect_pses}]);
    $pse->add_param(asp_id => $pse_params->{assembly_project}->asp_id);
    $pse->add_param(project_dir => $self->assembly_directory);
    $pse->add_param(pps_id => $pse_params->{process_param_set}->id);

    unless ($pse->confirmable) {
        $self->error_message("PSE is not confirmable");
        return;
    }
    $pse->confirm;

    my $bridge = GSC::Sequence::AnalysisOutputPSE->get(pse_id => $pse->id);
    unless ($bridge) {
        $self->error_message("Could not get analysis_output_pse");
        return;
    }

    unless ($pse->post_confirm) {
        $self->error_message("pse failed post_confirm");
        return;
    }

    my $file = $pse->output_file_name;
    my $out_obj = $pse->get_output_file_object($file);
    unless (ref $out_obj) {
        $self->error_message("Could not get the output file object");
        return;
    }

    return $pse;
}
