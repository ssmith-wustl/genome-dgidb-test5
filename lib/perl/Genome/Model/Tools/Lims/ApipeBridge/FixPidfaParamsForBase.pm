package Genome::Model::Tools::Lims::ApipeBridge::FixPidfaParamsForBase;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::Lims::ApipeBridge::FixPidfaParamsForBase { 
    is => 'Command::V2',
    is_abstract => 1,
    has_optional => [
        pidfa_id => {
            is => 'Integer',
            doc => 'Id of PIDFA to fix it\'ssolexa params.',
        },
        prior_id => {
            is => 'Integer',
            doc => 'Id of PIDFA prior PSE to fix said PIDFA\'s solexa params.',
        },
    ],
};

sub help_brief { return 'Fix PIDFA PSE params for '.$_[0]->instrument_data_type; }
sub help_detail { return 'Given a PIDFA or PIDFA\'s prior PSE, this command can fix some broken '.$_[0]->instrument_data_type.' PIDFAs. After fixing, schedule the pse by using "sw --sched ${PIDFA_ID}"'; }

sub _starting_points { 
    my $self = shift;
    my @starting_points = (qw/ prior_id pidfa_id /);
    push @starting_points, $self->_additional_starting_points if $self->can('_additional_starting_points');
    return @starting_points;
}

sub execute {
    my $self = shift;
    $self->status_message('Fix PIDFA params for '.$self->instrument_data_type.'...');

    my $starting_point_method = $self->_get_init_method;
    return if not $starting_point_method;

    my ($pidfa, $prior) = $self->$starting_point_method;
    return if not $pidfa;

    $self->status_message('PIDFA: '.$pidfa->id);
    $self->status_message('Prior PSE id: '.$prior->id);
    $self->status_message('Prior process: '.$prior->process_to);

    if ( not grep { $prior->process_to eq $_ } $self->valid_prior_processes ) {
        $self->error_message('Invalid prior process for 454!');
        next;
    }

    my $sequence_item = $self->_get_sequence_item_from_prior($prior);
    return if not $sequence_item;
    $self->status_message('Instrument data: '.$sequence_item->id);

    my %params_to_fix = (
        instrument_data_id => $sequence_item->id,
        instrument_data_type => $self->instrument_data_type,
    );
    my %additional_params_to_fix = $self->_additional_params_to_fix;
    for my $param_name ( keys %params_to_fix ) {
        my $new_param_value = $self->_fix_param($pidfa, $param_name, $params_to_fix{$param_name});
        return if not $new_param_value;
    }

    $self->status_message('Done');
    return 1;
}

sub _get_init_method {
    my $self = shift;

    my @starting_points = grep { defined $self->$_ } $self->_starting_points;
    if ( not @starting_points ) {
        $self->error_message('No starting point indicated! Select from '.join(', ', @starting_points));
        return;
    }
    elsif ( @starting_points > 1 ) {
        $self->error_message('Multiple starting points indicated! Plese select only one.');
        return;
    }

    return '_init_with_'.$starting_points[0];
}

sub _init_with_prior_id {
    my $self = shift;

    my $prior = GSC::PSE->get(id => $self->prior_id);
    if ( not $prior ) {
        $self->error_message('Failed to get prior PSE for id!'. $self->prior_id);
        return;
    }

    my ($tp_pse) = GSC::TppPSE->get(prior_pse_id => $prior->id);
    if ( not $tp_pse ) {
        $self->error_message('No transfer pattern pse for prior! '.$self->prior_id);
        return;
    }

    if ( not $tp_pse->pse_id ) {
        $self->error_message('No PIDFA pse id in transfer pattern for prior!');
        return;
    }

    my $pidfa = GSC::PSE->get(id => $tp_pse->pse_id, ps_id => 3870);
    if ( not $pidfa ) {
        $self->error_message('Failed to get PIDFA for id! '.$tp_pse->pse_id);
        return;
    }

    return ($pidfa, $prior);
}

sub _init_with_pidfa_id {
    my $self = shift;

    my $pidfa = GSC::PSE->get(id => $self->pidfa_id, ps_id => 3870);
    if ( not $pidfa ) {
        $self->error_message('Failed to get PIDFA for id! '.$self->pidfa_id);
        return;
    }

    my ($tp_pse) = GSC::TppPSE->get(pse_id => $pidfa->id);
    if ( not $tp_pse ) {
        $self->error_message('No transfer pattern pse for PIDFA! '.$self->pidfa_id);
        return;
    }#my ($prior_id) = $pidfa->added_param('control_pse_id'); 

    if ( not $tp_pse->prior_pse_id ) {
        $self->error_message('No prior pse id iun transfer pattern for PIDFA!');
        return;
    }

    my $prior = GSC::PSE->get(pse_id => $tp_pse->prior_pse_id);
    if ( not $prior ) {
        $self->error_message('Failed to get prior PSE for id!'. $tp_pse->prior_pse_id);
        return;
    }

    return ($pidfa, $prior);
}

sub _additional_params_to_fix { return; }
sub _fix_param {
    my ($self, $pidfa, $param_name, $param_value) = @_;

    die 'No PIDFA' if not $pidfa;
    die 'No param name' if not $param_name;
    die 'No param value' if not $param_value;

    my $param_display_name = join(' ', split('_', $param_name));

    # Remove extra params
    my @params = GSC::PSEParam->get(pse_id => $pidfa->id, param_name => $param_name);
    $self->status_message(ucfirst($param_display_name).' params: '.@params);
    for ( my $i = 1; $i < $#params; $i++ ) {
        $params[$i]->delete;
    }

    # Make sure the one left over is correct, if not delete and create a new one
    $self->status_message("Current $param_display_name: ".( @params ? $params[0]->param_value : 'NULL' ));
    if ( not @params or $params[0]->param_value ne $param_value ) {
        $params[0]->delete if @params;
        $pidfa->add_param($param_name => $param_value);
        my ($new_param_value) = $pidfa->added_param($param_name);
        $self->status_message("New $param_display_name: $new_param_value");
    }

    return 1;
}

1;

