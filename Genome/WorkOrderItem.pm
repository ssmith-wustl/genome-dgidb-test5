package Genome::WorkOrderItem;

use strict;
use warnings;

use Genome;

use Carp 'confess';
use Data::Dumper 'Dumper';

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
        unless ( $seq_item ) { # very bad
            confess "Can't get sequence item (".$woi_sp->seq_id.") for work order item (".$self->id.").";
        }
        push @seq_items, $seq_item;
    }

    return @seq_items;
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
    
    my @sequence_products = $self->sequence_products;
    if ( @sequence_products ) {
        my %instrument_data_ids;
        for my $sequence_product ( @sequence_products ) {
            if ( $sequence_product->isa('GSC::Sequence::Read') ) {
                $instrument_data_ids{ $sequence_product->prep_group_id } = 1;
            }
            else {
                $instrument_data_ids{ $sequence_product->seq_id } = 1;
            }
        }

        my %model_ids;
        for my $instrument_data_id ( keys %instrument_data_ids ) {
            my $ida = Genome::Model::InstrumentDataAssignment->get(
                instrument_data_id => $instrument_data_id,
            );
            next unless $ida; # ok, not assigned
            $model_ids{ $ida->model_id } = 1;
        }

        return unless %model_ids;

        return Genome::Model->get(id => [ keys %model_ids ]);
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

#$HeadURL$
#$Id$
