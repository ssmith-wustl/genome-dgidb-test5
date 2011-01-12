package Genome::RefCov::ROI::Bed;

use strict;
use warnings;

use Genome;

class Genome::RefCov::ROI::Bed {
    is => ['Genome::RefCov::ROI::FileI'],
    has => [
        _all_regions => { },
    ],
};

sub _read_file {
    my $self = shift;
    my $fh = IO::File->new($self->file,'r');
    while (my $line = $fh->getline) {
        chomp($line);
        my ($chr,$start,$end,$name,$score,$strand) = split("\t",$line);
        unless (defined($chr) && defined($start) && defined($end)) {
            next;
        }
        #BED format uses zero-based start coordinate, convert to 1-based
        $start += 1;
        my $wingspan = $self->wingspan;
        if ($wingspan) {
            $start -= $wingspan;
            $end += $wingspan;
        }
        my %region = (
            name => $name,
            chrom => $chr,
            start => $start,
            end => $end,
        );
        if (defined($strand)) {
            $region{strand} = $strand;
        }
        $self->_add_region(\%region);
    }
    $fh->close;
    return 1;
}

sub next_region {
    my $self = shift;
    unless ($self->_all_regions) {
        my $regions = $self->all_regions;
        $self->_all_regions($regions);
    }
    return shift(@{$self->_all_regions});
}

1;
