package Genome::Capture::Oligo;

use strict;
use warnings;

use Genome;

class Genome::Capture::Oligo {
    table_name => q|
        (select
            CAPTURE_STAG_ID tag_id,
            AMPLIFICATION_TARGET_ID target_id,
            ATC_ID id,
            CREATION_EVENT_ID pse_id
        from amplification_target_capture@oltp
        ) capture_oligo
    |,
    id_by => [
        id => { },
    ],
    has => [
        target_id => {},
        target => {
            is => 'Genome::Capture::Target',
            id_by => 'target_id',
        },
        tag_id => {},
        tag => {
            calculate_from => 'sequence_tag_id',
            calculate => q|return GSC::Sequence::Tag::Capture->get($sequence_tag_id);|,
        },
        pse_id => { },
    ],
    has_many_optional => {
        _set_oligos => {
            is => 'Genome::Capture::SetOligo',
            reverse_as => 'oligo',
        },
        sets => {
            via => '_set_oligos',
            to => 'set',
        }
    },
    doc         => '',
    data_source => 'Genome::DataSource::GMSchema',
};


sub gff {
    my $self = shift;
    my $tag = $self->tag;
    # Method found in GSC::Sequence::Tag
    return $tag->gff_text_v2;
}

1;
