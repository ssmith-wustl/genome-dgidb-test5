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
            is_paired_end       => { via => "run_region_454", to => "paired_end" },
    ],
};

sub get_or_create_from_read_set_id {
    my $class = shift;
    my $read_set_id = shift;

    my @read_sets = $class->_dw_class->get($read_set_id);
    unless (@read_sets) {
        die("Failed to find specified read set: " . $read_set_id);
    }
    if (@read_sets > 1) {
        die("Found more than one read set: ". $read_set_id);
    }
    my $read_set = $read_sets[0];

    my $run = Genome::RunChunk->get(
                                     seq_id => $read_set_id,
                                 );

    my $run_name = $read_set->run_name;
    my $sample_name = $read_set->sample_name;
    unless ($sample_name) {
        die "Sample name not found for read set: '$read_set_id'";
    }
    my $sequencing_platform = '454';
    my $lane = $read_set->region_number;
    my $full_path = '/gscmnt/833/info/medseq/sample_data/'. $read_set->run_name .'/'. $read_set->region_id .'/';

    if ($run) {
        if ($run->sequencing_platform ne $sequencing_platform) {
            die("Bad sequencing_platform value $sequencing_platform.  Expected " . $run->sequencing_platform);
        }
        if ($run->run_name ne $run_name) {
            die("Bad run_name value $run_name.  Expected " . $run->run_name);
        }
        if ($run->full_path ne $full_path) {
            warn("Run $run_name has changed location to $full_path from " . $run->full_path);
            $run->full_path($full_path);
        }
        if ($run->subset_name ne $lane) {
            die("Bad lane/subset value $lane.  Expected " . $run->subset_name);
        }
        if ($run->sample_name ne $sample_name) {
            die("Bad sample_name value $sample_name.  Expected " . $run->sample_name);
        }
        return $run;
    } else {
        my $self = $class->SUPER::create(
                                         genome_model_run_id => $read_set_id,
                                         seq_id => $read_set_id,
                                         run_name => $run_name,
                                         full_path => $full_path,
                                         subset_name => $lane,
                                         sequencing_platform => $sequencing_platform,
                                         sample_name => $sample_name,
                                     );
        unless ($self) {
            die("Failed to create run record information for $run_name, $lane ($read_set_id)");
        }
        return $self;
    }
}

sub _dw_class { 'GSC::RunRegion454' }

sub _desc_dw_obj {
    my $class = shift;
    my $obj = shift;
    return "(" . $obj->id . ")";
}

1;

