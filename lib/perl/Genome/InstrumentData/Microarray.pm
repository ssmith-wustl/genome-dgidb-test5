package Genome::InstrumentData::Microarray;

use strict;
use warnings;

use Genome;

class Genome::InstrumentData::Microarray {
};

sub get_snpid_hash_for_variant_list {
    my $class = shift;
    my $instrument_data = shift || die 'No instrument data given';
    my $variation_list_build = shift || die 'No variation list build';

    my $platform = lc($instrument_data->sequencing_platform);
    my $chip_attribute = $instrument_data->attributes(attribute_label => 'chip_name');
    my $chip = ( $chip_attribute ? lc($chip_attribute->attribute_value) : '' );
    my $version_attribute = $instrument_data->attributes(attribute_label => 'version');
    my $version = ( $chip_attribute ? lc($version_attribute->attribute_value) : '' );

    my $allocation = Genome::Disk::Allocation->get(allocation_path => "microarray_data/$platform-$chip-$version");
    return if not $allocation;

    my $snp_map_path = $allocation->absolute_path . '/mapping.tsv';
    Carp::confess('No snp id mapping file in '.$allocation->absolute_path) if not -s $snp_map_path;

    my $fh = eval{ Genome::Sys->open_file_for_reading($snp_map_path); };
    Carp::confess('Failed to open snp id mapping file! '.$snp_map_path) if not $fh;

    my $old_to_new_snpid_map;
    while ( my $mapping = $fh->getline ) {
        chomp $mapping;
        my ($old_id, $new_id) = split /\t/, $mapping;
        $old_to_new_snpid_map->{$old_id} = $new_id;
    }
    return $old_to_new_snpid_map;
}
