package Genome::InstrumentData::Command::RemoveAlignmentDirectory;

use strict;
use warnings;

use Genome;

class Genome::InstrumentData::Command::RemoveAlignmentDirectory {
    is => 'Genome::InstrumentData::Command',
    has => [
            aligner_name => {
                             is => 'Text',
                             doc => 'The name of the aligner used to create alignment data',
                         },
            reference_sequence_name => {
                                        is => 'Text',
                                        doc => 'The name of the reference sequence to which instrument data was aligned',
                                    },
        ],
};

sub execute {
    my $self = shift;

    my $instrument_data = $self->instrument_data;
    unless ($instrument_data) {
        $self->error_message('Could not find instrument data for instrument data id '. $self->instrument_data_id);
        return;
    }
    $instrument_data->remove_alignment_directory_for_aligner_and_refseq($self->aligner_name,$self->reference_sequence_name);
    return 1;
}

1;
