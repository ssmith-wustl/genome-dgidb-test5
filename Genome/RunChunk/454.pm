package Genome::RunChunk::454;

use strict;
use warnings;

use Genome;
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
            is_paired_end       => { via => "run_region_454", to => "paired_end" },
    ],
};

sub resolve_sequencing_platform {
    return '454';
}

sub resolve_subset_name {
    my $class = shift;
    my $read_set = shift;
    return $read_set->region_number;
}

sub resolve_full_path{
    my $class = shift;
    my $read_set = shift;

    my $full_path = '/gscmnt/833/info/medseq/sample_data/'. $read_set->run_name .'/'. $read_set->region_id .'/';
    return $full_path;
}

sub _dw_class { 'GSC::RunRegion454' }

sub _desc_dw_obj {
    my $class = shift;
    my $obj = shift;
    return "(" . $obj->id . ")";
}

1;

