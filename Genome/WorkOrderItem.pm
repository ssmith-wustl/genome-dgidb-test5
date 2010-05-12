package Genome::WorkOrderItem;

use strict;
use warnings;

use above 'Genome';

use Carp 'confess';
use Data::Dumper 'Dumper';

#        dna => { 
#            is => 'Genome::Model::Build', 
#            reverse_as => 'model', 
#            is_many => 1 
#        },
class Genome::WorkOrderItem {
    table_name => '(SELECT * FROM work_order_item@oltp) work_order_item',
    id_by => [
        woi_id => {
            is => 'Integer',
            len => 10,
            column_name => 'WOI_ID',
        },
    ],    
    has => [
        setup_wo_id => {
            is => 'Integer',
            len => 10,
        },
        status => {
            is => 'Text',
            len => 32,
        },
        work_order => {
            is => 'Genome::WorkOrder',
            is_many => 1,
            id_by => 'setup_wo_id',
            doc => 'The work order for this item.',
        },
    ],
    has_optional => [
        barcode => {
            is => 'Text',
            len => 16,
        },
        dna_id => {
            is => 'Integer',
            len => 20,
        },
        sample => {
            is => 'Genome::Sample',
            id_by => 'dna_id',
        },
        parent_woi_id => {
            is => 'Integer',
            len => 10,
        },
        pipeline_id => {
            is => 'Integer',
            len => 10,
        },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
};

sub sequence_products {
    my $self = shift;

    my @woi_sp = GSC::WoiSequenceProduct->get(woi_id => $self->id)
        or return;

    my @seq_items;
    for my $woi_sp ( @woi_sp ) {
        my $seq_item = GSC::Sequence::Item->get(seq_id => $woi_sp->seq_id);

        # woi_sequence_product contains all the info twice right now-
        # once the old way (solexa run lane) that maps to solexa_lane_summary
        # second the new way (index illumina) maps to index_illumina
        next if $seq_item->sequence_item_type eq 'solexa run lane';

        unless ( $seq_item ) { # very bad
            confess "Can't get sequence item (".$woi_sp->seq_id.") for work order item (".$self->id.").";
        }
        push @seq_items, $seq_item;
    }

    return @seq_items;
}

sub instrument_data {
    my $self = shift;

    my @instrument_data_ids = $self->instrument_data_ids
        or return;

    my @instrument_data = Genome::InstrumentData->get(\@instrument_data_ids);
    return @instrument_data;
}

sub instrument_data_ids {

    my $self = shift;

    my @sequence_products = $self->sequence_products
        or return;

    my %instrument_data_ids;
    for my $sequence_product ( @sequence_products ) {
        if ( $sequence_product->isa('GSC::Sequence::Read') ) {
            $instrument_data_ids{ $sequence_product->prep_group_id } = 1;
        } elsif ($sequence_product->isa('GSC::IndexIllumina')) {
            $instrument_data_ids{ $sequence_product->analysis_id } = 1;
        } else {
            $instrument_data_ids{ $sequence_product->seq_id } = 1;
        }
    }

    return sort keys %instrument_data_ids;
}

sub models {
    my $self = shift;

    # Strategy
    # 1 - Real way.
    #      This will work for 454 and Solexa now, and
    #      eventually for sanger.  For sanger, the reads will be tracked,
    #      so we'll need to get the 'prep_group_id' for each read, then
    #      get the inst data assignment
    #  a - get work order seq products 
    #  b - if seq prod is a read get it's prep_group_id else (solexa/454) 
    #       use seq_id
    #  c - get models via inst data assignments (inputs eventually)
    #  

    my @instrument_data_ids = $self->instrument_data_ids();

    if (@instrument_data_ids) {
    
        my @instrument_data_assignments = 
            Genome::Model::InstrumentDataAssignment->get(instrument_data_id => \@instrument_data_ids);
        return unless @instrument_data_assignments;

        my %model_ids = map { $_->model_id => 1 } @instrument_data_assignments;
        return unless %model_ids;

        return Genome::Model->get(id => [ keys %model_ids ]);

    } else {
        $self->warning_message("No sequence products (instrument data) found for work order item (".$self->id.").  Attempting to get models via dna_id.");
    }

    # 2 - Round about, not so accurate way, but works sometimes.
    #      WOI have dna id or barcode.  We only get for barcode until someone
    #      wants to write the logic.  But once the sanger reads are back filled
    #      into the woi seq product table, this should be removed. Ther should be
    #      a dna_id OR barcode
    #
    #  a - get dna_id.  if no dna id, then this doesn't work.  die.
    #  b - get models w/ subject_id == dna_id
    #  
    
    if ( $self->dna_id ) {
        return Genome::Model->get(subject_id => $self->dna_id);
    }

    if ( $self->barcode ) {
        confess "Can't get models for a work order item (".$self->id.") that only has a barcode, and no sequence products or dna_id.";
    }
}

sub pse_statuses {

    my ($self) = @_;

    my $pses = {};

    for my $sp ($self->sequence_products()) {

        if ($sp->isa('GSC::IndexIllumina')) {

            my $creation_pse = $sp->get_creation_event();
            my $pidfa_pse = $creation_pse->get_first_active_subsequent_pse_with_process_to('prepare instrument data for analysis');
            my $queue_pse = $creation_pse->get_first_active_subsequent_pse_with_process_to('queue instrument data for genome modeling');
            my $setup_pse = $creation_pse->get_first_prior_pse_with_process_to('set up flow cell');

            $pses->{$creation_pse->process_to}->{$creation_pse->pse_status}++;
            $pses->{$pidfa_pse->process_to}->{$pidfa_pse->pse_status}++;
            $pses->{$setup_pse->process_to}->{$setup_pse->pse_status}++;
        } elsif ($sp->isa('GSC::RegionIndex454')) {

        } else {

        }
    }

    $DB::single = 1;
    return $pses;
}

# prepare dna beads
# setup flow cell
   

# 454: demux 454 regions
# illumina: copy sequence files
# 3730: analyze traces





#$HeadURL$
#$Id$
