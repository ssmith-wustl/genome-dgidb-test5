package Genome::WorkOrderItem;

use strict;
use warnings;

use above 'Genome';

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
        models => {
            is => 'Genome::Model',
            calculate_from => ['dna_id'],
            calculate => q|Genome::Model->get(subject_id => $dna_id)| 
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
        my @instrument_data_inputs = Genome::Model::Input->get(
            name => 'instrument_data',
            value_id => \@instrument_data_ids,
            value_class_name => 'Genome::InstrumentData',
        );
        return unless @instrument_data_inputs;
        my %model_ids = map { $_->model_id => 1 } @instrument_data_inputs;
        return unless %model_ids;
        return Genome::Model->get(genome_model_id => [ keys %model_ids ]);
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

sub _summarize {

    my ($process_to) = @_;
    my @initials;

    if (length($process_to) > 25) {
        my @words = split(/\s+/,$process_to);
        push @initials, uc(substr($_, 0, 1)) for @words; 
        return join('', @initials);
    }

    return $process_to;
}

sub _hash_up {

    my ($events, $pse, $sort_order) = @_;

    my $status     = $pse->pse_status;
    my $process_to = _summarize( $pse->process_to );

    return {
        count      => $events->{'production'}->{$process_to}->{$status}->{'count'} + 1,
        sort_order => $sort_order,
    };
}

sub event_statuses {

    my ($self) = @_;

    my $events = {};
    for my $sp ($self->sequence_products()) {

        my $status = {};

        # get event statuses from LIMS
        if ($sp->isa('GSC::IndexIllumina')) {

            my $creation_pse = $sp->get_creation_event();
            my $setup_pse = $creation_pse->get_first_prior_pse_with_process_to('set up flow cell');
            my $pidfa_pse = $creation_pse->get_first_active_subsequent_pse_with_process_to('prepare instrument data for analysis');
            my $queue_pse = $creation_pse->get_first_active_subsequent_pse_with_process_to('queue instrument data for genome modeling');

            # put the pses in 3 status buckets- "pending", "completed", "failed"
            for my $pse ($creation_pse, $setup_pse, $pidfa_pse, $queue_pse) {

                my $pse_status = $pse->pse_status();
                my @completed = qw(COMPLETED);
                my @failed = qw(FAILED);

                # default status is "pending"
#                $status->{$pse->pse_id} = $pse_status;
                $status->{$pse->pse_id} = 'pending';

                if (grep /^$pse_status$/i, @completed) {
                    $status->{$pse->pse_id} = 'completed';
                } elsif (grep /^$pse_status$/i, @failed) {
                    $status->{$pse->pse_id} = 'failed';
                }
            }

            # generate lane summary
            $events->{'production'}->{_summarize($creation_pse->process_to)}->{$status->{$creation_pse->pse_id}} = _hash_up($events, $creation_pse, 2);

            # set up flow cell
            $events->{'production'}->{_summarize($setup_pse->process_to)}->{$status->{$setup_pse->pse_id}} = _hash_up($events, $setup_pse, 1);
$DB::single = 1;
            # PIDFA
            $events->{'production'}->{_summarize($pidfa_pse->process_to)}->{$status->{$pidfa_pse->pse_id}} = _hash_up($events, $pidfa_pse, 3);

            # queue inst data
            $events->{'production'}->{_summarize($queue_pse->process_to)}->{$status->{$queue_pse->pse_id}} = _hash_up($events, $queue_pse, 4);

        } elsif ($sp->isa('GSC::RegionIndex454')) {

        } else {

        }

        # get statuses of latest builds from canonical models
        my $sample = $self->sample();
        my $model = $sample->canonical_model();

        if ($model) {
            my $build = $model->latest_build();
            my $build_status = $build->master_event_status();

            # same status buckets as pses- pending, completed, failed
            if ($build_status =~ /SUCCEEDED/i) {
                $build_status = 'completed';
            } elsif ($build_status =~ /FAILED/i) {
                $build_status = 'failed';
            } else {
                # default status is same as PSEs- "pending"
                $build_status = 'pending';
            }

            $events->{'analysis'}->{'builds'}->{$build_status}->{'count'}++;
            $events->{'analysis'}->{'builds'}->{$build_status}->{'sort_order'} = 5;
        }
    }

    return $events;
}





# prepare dna beads
# setup flow cell
   

# 454: demux 454 regions
# illumina: copy sequence files
# 3730: analyze traces





#$HeadURL$
#$Id$
