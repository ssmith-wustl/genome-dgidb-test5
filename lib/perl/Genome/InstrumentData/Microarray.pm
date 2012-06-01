package Genome::InstrumentData::Microarray;

use strict;
use warnings;

use Genome;

class Genome::InstrumentData::Microarray {
};

sub get_snpid_hash_for_variant_list {
    my $class = shift;
    my $instrument_data = shift || die 'No instrument data given';
    my $chip = shift;
    my $version = shift;

    my $platform = $instrument_data->sequencing_platform;
    my $allocation = Genome::Disk::Allocation->get(allocation_path => "microarray_data/$platform-$chip-$version") || die "No mapping available for $platform-$chip-$version";
    my $snp_map_path = $allocation->absolute_path . 'mapping.tsv';

    my $old_to_new_snpid_map;
    my @mapping = Genome::Sys->read_file($snp_map_path);
    for my $mapping (@mapping){
        chomp $mapping;
        my ($old_id, $new_id) = split "\t", $mapping;
        $old_to_new_snpid_map->{$old_id} = $new_id;
    }
    return $old_to_new_snpid_map;
}
