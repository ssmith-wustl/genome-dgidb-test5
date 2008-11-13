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
        calculate => q| GSC::RunRegion454->get($id); |,
        calculate_from => [qw/ id  /]
    },
    region_id           => { via => "run_region_454" },
    library_name        => { via => "run_region_454" },
    total_reads         => { via => "run_region_454", to => "total_key_pass" },
    is_paired_end       => { via => "run_region_454", to => "paired_end" },
    ],
};

sub _default_full_path {
    my $self = shift;
    return sprintf('%s/%s/%s', $self->_sample_data_base_path, $self->run_name, $self->id);
}

1;

#$HeadURL$
#$Id$
