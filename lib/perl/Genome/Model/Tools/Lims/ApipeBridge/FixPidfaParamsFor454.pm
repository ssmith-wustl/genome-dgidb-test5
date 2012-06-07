package Genome::Model::Tools::Lims::ApipeBridge::FixPidfaParamsFor454;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::Lims::ApipeBridge::FixPidfaParamsFor454 { 
    is => 'Genome::Model::Tools::Lims::ApipeBridge::FixPidfaParamsForBase', 
};

sub instrument_data_type { return '454'; }
sub valid_prior_processes { return ( 'analyze 454 output', 'analyze 454 run', 'analyze 454 region', 'demux 454 region' ); }

sub _get_sequence_item_from_prior {
    my ($self, $prior) = @_;

    my @run_regions = $prior->get_454_run_regions;
    if ( not @run_regions ) {
        $self->error_message('No 454 run regions for prior PSE!');
        return;
    }
    my @region_ids = map {$_->region_id() } @run_regions;
    my @region_indexes = GSC::RegionIndex454->get(region_id => \@region_ids);
    if ( not @region_indexes ) {
        $self->error_message('No 454 region indexes for prior PSE!');
        return;
    }
    elsif ( @region_indexes > 1 ) {
        $self->status_message('More than one 454 region index found for prior PSE. This can happen, but cannot be fixed with this command. Sorry.');
        return;
    }

    return $region_indexes[0];
}

1;

