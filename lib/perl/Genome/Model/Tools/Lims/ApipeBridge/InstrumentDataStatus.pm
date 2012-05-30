package Genome::Model::Tools::Lims::ApipeBridge::InstrumentDataStatus;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::Lims::ApipeBridge::InstrumentDataStatus { 
    is => 'Command::V2',
    has => [
        summary_only => {
            is => 'Boolean',
            is_optional => 1,
            doc => 'Only show the summary of the instrument data status.',
        },
    ],
};

sub help_brief { return 'Show LIMS-APIPE status of instrument data'; }
sub help_detail { return help_brief(); }

sub execute {
    my $self = shift;

    # Get 'new' instrument data
    my %new_instrument_data = map { $_->id => $_ } Genome::InstrumentData->get(
       'attributes.attribute_label' => 'tgi_lims_status',
       'attributes.attribute_value' => [qw/ new /],
    );

    # Get 'failed' instrument data
    my %failed_instrument_data = map { $_->id => $_ } Genome::InstrumentData->get(
       'attributes.attribute_label' => 'tgi_lims_status',
       'attributes.attribute_value' => [qw/ failed /],
    );

    # Get the inprogress QIDFGMs mapped to instrument data
    my @qidfgms = GSC::PSE->get(
        ps_id => 3733,
        pse_status => 'inprogress',
    );
    
    # Map QIDFGMs to instrument data
    my $join = ' ';
    my ($status, %totals, %statuses);
    for my $qidfgm ( @qidfgms ) {
        my ($instrument_data_id) = $qidfgm->added_param('instrument_data_id');
        my ($instrument_data_type) = $qidfgm->added_param('instrument_data_type');
        $instrument_data_type =~ s/\s+/_/g;
        if ( not $instrument_data_id ) {
            $self->warning_message('No instrument data id for QIDFGM! '.$qidfgm->id);
            next;
        }
        my $instrument_data_status;
        if ( delete $new_instrument_data{$instrument_data_id} ) {
            $totals{synced}++;
            $instrument_data_status = 'new';
        }
        elsif ( delete $failed_instrument_data{$instrument_data_id} ) {
            $totals{synced}++;
            $instrument_data_status = 'failed';
        }
        else {
            $totals{na}++;
            $instrument_data_status = 'na';
        }
        $statuses{ $instrument_data_type.'('.$instrument_data_status.')' }++;
        $status .= join(' ', $instrument_data_id, $instrument_data_type, $instrument_data_status, $qidfgm->id)."\n";
    }
    $totals{qidfgm} = @qidfgms;
    $totals{missing} = keys(%new_instrument_data) + keys(%failed_instrument_data);
    $totals{inprogress} = $totals{qidfgm} - $totals{missing};

    $self->status_message( join($join, (qw/ id type status qidfgm /))."\n$status" ) if not $self->summary_only and $status;
    $self->status_message(
        join(' ', 'STATUS:', map { $_.'='.$statuses{$_} } sort keys %statuses)
    );
    $self->status_message(
        join(' ', 'TOTALS:', map { $_.'='.$totals{$_} } sort keys %totals)
    );

    return 1;
}

1;

