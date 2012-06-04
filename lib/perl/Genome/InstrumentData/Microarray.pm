package Genome::InstrumentData::Microarray;

use strict;
use warnings;

use Genome;

class Genome::InstrumentData::Microarray {
};

sub get_snpid_hash_for_variant_list {
    my $self = shift;
    my $instrument_data = shift || die 'No instrument data given';
    my $variation_list_build = shift || die 'No variation list build';
    $self->status_message('Get snp id hash for variant list...');

    $self->status_message("Instrument data: ".$instrument_data->id);
    my $platform = lc($instrument_data->sequencing_platform);
    $self->status_message("Platform: $platform");
    my $chip_attribute = $instrument_data->attributes(attribute_label => 'chip_name');
    my $chip = ( $chip_attribute ? lc($chip_attribute->attribute_value) : '' );
    $self->status_message("Chip: $chip");
    my $version_attribute = $instrument_data->attributes(attribute_label => 'version');
    my $version = ( $chip_attribute ? lc($version_attribute->attribute_value) : '' );
    $self->status_message("Version: $version");

    $self->status_message('Looking for allocation for snp mapping file...');
    my $allocation = Genome::Disk::Allocation->get(allocation_path => "microarray_data/$platform-$chip-$version");
    if ( not $allocation ) {
        $self->status_message('No allocation found! This may be exepected.');
        return;
    }
    $self->status_message('Found allocation: '.$allocation->id);

    my $snp_map_path = $allocation->absolute_path . '/mapping.tsv';
    $self->status_message('Snp mapping file: '.$snp_map_path);
    Carp::confess('No snp id mapping file in '.$allocation->absolute_path) if not -s $snp_map_path;

    my $fh = eval{ Genome::Sys->open_file_for_reading($snp_map_path); };
    Carp::confess('Failed to open snp id mapping file! '.$snp_map_path) if not $fh;

    my %old_to_new_snpid_map;
    while ( my $mapping = $fh->getline ) {
        chomp $mapping;
        my ($old_id, $new_id) = split /\t/, $mapping;
        Carp::confess("Invalid line in snp mapping file! '$mapping'") if not defined $old_id and not defined $new_id;
        $old_to_new_snpid_map{$old_id} = $new_id;
    }

    $self->status_message('Get snp id hash for variant list...OK');
    return \%old_to_new_snpid_map;
}
