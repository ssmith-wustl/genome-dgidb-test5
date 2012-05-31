package Genome::Model::Tools::Lims::ApipeBridge::FixPidfaParamsFor454;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::Lims::ApipeBridge::FixPidfaParamsFor454 { 
    is => 'Command::V2',
    has => [
        pidfa_ids => {
            is => 'Integer',
            is_many => 1,
            shell_args_position => 1,
            doc => 'Ids of PIDFAs to fix 454 params.',
        },
    ],
};

sub help_brief { return 'Fix PIDFA 454 params'; }
sub help_detail { return 'This command can fix some broken 454 PIDFAs. After fixing, schedule the pse by using "sw --sched ${PSE_ID}'; }

sub execute {
    my $self = shift;
    $self->status_message('Fix PIDFA params for 454...');

    my @pidfa_ids = $self->pidfa_ids;
    if ( not @pidfa_ids ) {
        $self->error_message('No PIDFA ids given!');
        return;
    }
    $self->status_message('PIDFA ids: '.@pidfa_ids);

    my @pidfas = GSC::PSE->get(id => \@pidfa_ids, ps_id => 3870);
    if ( not @pidfas ) {
        $self->error_message('No PIDFAs found for ids given!');
        return;
    }
    $self->status_message('PIDFAs found: '.@pidfas);

    my @valid_prior_processes = ( 'analyze 454 output', 'analyze 454 run', 'analyze 454 region', 'demux 454 region' );

    for my $pidfa ( @pidfas ) {
        $self->status_message('<# PIDFA: '.$pidfa->id.' #>');
        my ($prior_pse_id) = $pidfa->added_param('control_pse_id');
        if ( not $prior_pse_id ) {
            $self->error_message('No prior pse id for PIDFA!');
            next;
        }
        $self->status_message('Prior PSE id: '.$prior_pse_id);
        my $prior_pse = GSC::PSE->get($prior_pse_id);
        if ( not $prior_pse ) {
            $self->error_message('No prior PSE for id! '.$prior_pse_id);
            next;
        }
        $self->status_message('Prior process: '.$prior_pse->process_to);
        if ( not grep { $prior_pse->process_to eq $_ } @valid_prior_processes ) {
            $self->error_message('Invalid prior process for 454!');
            next;
        }

        my @run_regions = $prior_pse->get_454_run_regions;
        if ( not @run_regions ) {
            $self->error_message('No 454 run regions for prior PSE!');
            next;
        }
        my @region_ids = map {$_->region_id() } @run_regions;
        my @region_indexes = GSC::RegionIndex454->get(region_id => \@region_ids);
        if ( not @region_indexes ) {
            $self->error_message('No 454 region indexes for prior PSE!');
            next;
        }
        elsif ( @region_indexes > 1 ) {
            $self->status_message('More than one 454 region index found for prior PSE. This can happen, but cannot be fixed with this command. Sorry.');
            next;
        }
        $self->status_message('Region index 454: '.$region_indexes[0]->id);

        # Remove extra inst data id params
        my @instrument_data_id_params = GSC::PSEParam->get(pse_id => $pidfa->id, param_name => 'instrument_data_id');
        $self->status_message('Instrument data id params: '.@instrument_data_id_params);
        for ( my $i = 1; $i < $#instrument_data_id_params; $i++ ) {
            $instrument_data_id_params[$i]->delete;
        }
        # Make sure the one left over is correct, if not delete and create a new one
        $self->status_message('Current instrument data id: '.( @instrument_data_id_params ? $instrument_data_id_params[0]->param_value : 'NULL' ));
        if ( not @instrument_data_id_params or $instrument_data_id_params[0]->param_value ne $region_indexes[0]->id ) {
            $instrument_data_id_params[0]->delete if @instrument_data_id_params;
            my ($new_param) = $pidfa->add_param(instrument_data_id => $region_indexes[0]->id);
            $self->status_message('Set instrument data id: '.$region_indexes[0]->id);
        }

        # Remove extra inst data type params
        my @instrument_data_type_params = GSC::PSEParam->get(pse_id => $pidfa->id, param_name => 'instrument_data_type');
        $self->status_message('Instrument data type params: '.@instrument_data_type_params);
        for ( my $i = 1; $i < $#instrument_data_type_params; $i++ ) {
            $instrument_data_type_params[$i]->delete;
        }
        $self->status_message('Current instrument data type: '.( @instrument_data_type_params ? $instrument_data_type_params[0]->param_value : 'NULL' ));
        # Make sure the one left over is correct, if not delete and create a new one
        if ( not @instrument_data_type_params or $instrument_data_type_params[0]->param_value ne '454' ) {
            $instrument_data_type_params[0]->delete if @instrument_data_type_params;
            my ($new_param) = $pidfa->add_param(instrument_data_type => '454');
            $self->status_message('Set instrument data type: 454');
        }
    }

    $self->status_message('Done');
    return 1;
}

1;

