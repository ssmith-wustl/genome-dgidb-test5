package Genome::Model::Tools::Lims::SamplesForWorkOrder;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::Lims::SamplesForWorkOrder {
    is => 'Command::V2',
    has_input => [
        work_order => {
            is => 'Number',
            doc => 'ID of the work order from which to extract samples',
            shell_args_position => 1,
        },
        show => {
            is => 'Text',
            doc => 'Controls which properties of the samples are displayed',
            is_optional => 1,
            default_value => 'id,name',
        },
    ],
    has_output => [
        _sample_ids => {
            is => 'Text',
            is_many => 1,
            is_transient => 1,
            is_optional => 1,
        },
    ],
};

sub execute {
    my $self = shift;

    my $work_order = GSC::Setup::WorkOrder->get($self->work_order);
    unless($work_order) {
        die $self->error_message('Failed to get a work order for input: ' . $self->work_order);
    }

    my @lims_samples;
    my @woi = $work_order->get_item;
    for my $item (@woi) {
        my $os = $item->get_dna->get_organism_sample;
        next unless $os;

        push @lims_samples, $os;
    }

    unless(@lims_samples) {
        $self->warning_message('No samples found on work order.');
        return 1;
    }

    $self->_sample_ids([map($_->id, @lims_samples)]);
    Genome::Sample::Command::List->execute(
        show => $self->show,
        filter => 'id:' . join('/', $self->_sample_ids),
    );
}

1;
