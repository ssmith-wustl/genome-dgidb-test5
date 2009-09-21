package Genome::Capture::Target;

use strict;
use warnings;

use Genome;

class Genome::Capture::Target {
    table_name => q|
        (select
            CAPTURE_STAG_ID sequence_tag_id,
            AMPLIFICATION_TARGET_ID sequence_target_id,
            ATC_ID id,
            CREATION_EVENT_ID pse_id
        from amplification_target_capture@oltp
        ) capture_target
    |,
    id_by => [
        id => { },
    ],
    has => [
        sequence_tag_id => {},
        sequence_target_id => {},
        pse_id => {},
        _sequence_tag => {
            calculate_from => 'sequence_tag_id',
            calculate => q|return GSC::Sequence::Tag::Capture->get($sequence_tag_id);|,
        }
    ],
    has_many_optional => {
        capture_set_targets => {
            is => 'Genome::Capture::SetTarget',
            reverse_id_by => 'capture_target',
        }
    },
    doc         => '',
    data_source => 'Genome::DataSource::GMSchema',
};


sub gff {
    my $self = shift;
    my $sequence_tag = $self->_sequence_tag;
    # Method found in GSC::Sequence::Tag
    return $sequence_tag->gff_text_v2;
}

1;
