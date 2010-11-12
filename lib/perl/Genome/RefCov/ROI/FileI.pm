package Genome::RefCov::ROI::FileI;

use strict;
use warnings;

use Genome;

my $DEFAULT_REGION_INDEX_SUBSTRING = 0;

class Genome::RefCov::ROI::FileI {
    has => [
        file => {
            is => 'String',
            doc => 'The file path of the defined regions/intervals',
        },
    ],
    has_optional => {
        region_index_substring => {
            default_value => $DEFAULT_REGION_INDEX_SUBSTRING,
        },
        wingspan => {
            is => 'Integer',
            doc => 'An integer distance to add to each end of a region.',
        },
    }
};

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);
    $self->_read_file;
    return $self;
}

sub chromosomes {
    my $self = shift;
    return keys %{$self->{chrom_regions}};
}

sub overlaps_regions {
    my $self = shift;
    my ($chr,$start,$stop) = @_;
    my $start_substr = substr($start, 0, $self->region_index_substring) || 0;
    my $stop_substr = substr($stop, 0, $self->region_index_substring) || 0;
    for (my $position_key = $start_substr; $position_key <= $stop_substr; $position_key++) {
        my $region_key = $chr .':'. $position_key;
        if ($self->{indexed_regions}->{$region_key}) {
            my @region_list = split(/\n/, $self->{indexed_regions}->{$region_key});
            foreach my $region (@region_list) {
                (my $region_start, my $region_stop) = split(/\t/, $region);
                if(($start >= $region_start && $start <= $region_stop) || ($stop >= $region_start && $stop <= $region_stop)) {
                    return 1;
                }
            }
        }
    }
    return 0;
}

sub chromosome_regions {
    my $self = shift;
    my $chrom = shift;
    unless ($self->{chrom_regions}->{$chrom}) {
        return;
    }
    return @{$self->{chrom_regions}->{$chrom}};
}

sub all_regions {
    my $self = shift;
    my @chromosomes = $self->chromosomes;
    my @regions;
    for my $chrom (@chromosomes) {
        push @regions, $self->chromosome_regions($chrom);
    }
    return @regions;
}

sub _add_region {
    my $self = shift;
    my $region = shift;
    unless ($region && ref($region) eq 'Genome::RefCov::ROI::Region') {
        die ('Must supply a Genome::RefCov::ROI::Region to method _add_region');
    }
    my $start = $region->start;
    my $stop = $region->end;
    my $start_substr = substr($start, 0, $self->region_index_substring) || 0;
    my $stop_substr = substr($stop, 0, $self->region_index_substring) || 0;
    for (my $position_key = $start_substr; $position_key <= $stop_substr; $position_key++) {
        my $region_key = $region->chrom . ':' . $position_key;
        $self->{indexed_regions}->{$region_key} .=  $start."\t". $stop ."\n";
    }
    push @{$self->{chrom_regions}->{$region->chrom}}, $region;
    return 1;
}

sub _read_file {
    die ('_read_file is an abstract method.  Please implement in '. __PACKAGE__);
}


1;
