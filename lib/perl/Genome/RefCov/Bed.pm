package Genome::RefCov::Bed;

use strict;
use warnings;

use Genome;

class Genome::RefCov::Bed {
    is => ['Genome::RefCov::RegionFileI'],
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
        my %region_params = (
            name => $name,
            chrom => $chr,
            start => $start,
            end => $end,
        );
        if (defined($strand)) {
            $region_params{strand} = $strand;
        }
        my $region = Genome::RefCov::Region->create(%region_params);
        $self->_add_region($region);
    }
    $fh->close;
    return 1;
}

1;
