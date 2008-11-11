package Genome::InstrumentData::454;

use strict;
use warnings;

use Genome;

class Genome::InstrumentData::454 {
    is  => 'Genome::InstrumentData',
    has => [
    run_region_454     => {
        doc => 'Lane representation from LIMS.  This class should eventually be a base class for data like this.',
        is => 'GSC::RunRegion454',
        calculate => q| GSC::RunRegion454->get($genome_model_run_id); |,
        calculate_from => [qw/ genome_model_run_id  /]
    },
    library_name        => { via => "run_region_454" },
    total_reads         => { via => "run_region_454", to => "total_key_pass" },
    is_paired_end       => { via => "run_region_454", to => "paired_end" },
    ],
};

sub resolve_full_path{
    my $self = shift;

    return sprintf('%s/%s/%s', $self->_sample_data_base_path, $self->run_name, $self->seq_id);
    #return '/gscmnt/833/info/medseq/sample_data/'. $read_set->run_name .'/'. $read_set->region_id .'/';
}

1;

#$HeadURL$
#$Id$
