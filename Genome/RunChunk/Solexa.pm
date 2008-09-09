package Genome::RunChunk::Solexa;

use strict;
use warnings;

use Genome;
use Genome::RunChunk;

class Genome::RunChunk::Solexa {
    is => [
           'Genome::RunChunk',
    ],
    has => [
        _run_lane_solexa    => {
                                doc => 'Lane representation from LIMS.  This class should eventually be a base class for data like this.',
                                is => 'GSC::RunLaneSolexa',
                                calculate => q| GSC::RunLaneSolexa->get($seq_id); |,
                                calculate_from => ['seq_id']
                            },
        short_name          => {
                                doc => 'The essential portion of the run name which identifies the run.  The rest is redundent information about the instrument, date, etc.',
                                is => 'String', 
                                calculate_from => ['run_name'],
                                calculate => q|($run_name =~ /_([^_]+)$/)[0]|
                            },
        library_name                    => { via => "_run_lane_solexa" },
        unique_reads_across_library     => { via => "_run_lane_solexa" },
        duplicate_reads_across_library  => { via => "_run_lane_solexa" },
        read_length                     => { via => "_run_lane_solexa" }, 

        #rename not to be platform specific and move up
        clusters                        => { via => "_run_lane_solexa" },
        is_paired_end                   => { 
                                             calculate_from => ['run_type'],
                                             calculate => q| if ($run_type =~ m/Paired End/) {
                                                                return 1;
                                                             }
                                                             else {
                                                                 return 0;
                                                             } |
                                           },
        run_type                        => { via => "_run_lane_solexa" },
        gerald_directory                => { via => "_run_lane_solexa" },
    ],
};

sub _dw_class { 'GSC::RunLaneSolexa' }

sub _desc_dw_obj {
    my $class = shift;
    my $obj = shift;
    return $obj->run_name . "/" . $obj->lane . " (" . $obj->id . ")";
}


1;
