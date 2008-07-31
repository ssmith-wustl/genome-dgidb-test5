package Genome::RunChunk::454;

use strict;
use warnings;

use above "Genome";
use Genome::RunChunk;

class Genome::RunChunk::454 {
    is  => 'Genome::RunChunk',
    has => [
            run_region_454     => {
                                    doc => 'Lane representation from LIMS.  This class should eventually be a base class for data like this.',
                                    is => 'GSC::RunRegion454',
                                    calculate => q| GSC::RunRegion454->get($seq_id); |,
                                    calculate_from => ['seq_id']
                                },
            library_name        => { via => "run_region_454" },
            total_reads         => { via => "run_region_454", to => "total_key_pass" },
            is_paired_end       => { calculate => q| return "unknown"; | },
    ],
};

sub _dw_class { 'GSC::RunRegion454' }

sub _desc_dw_obj {
    my $class = shift;
    my $obj = shift;
    return "(" . $obj->id . ")";
}

1;

