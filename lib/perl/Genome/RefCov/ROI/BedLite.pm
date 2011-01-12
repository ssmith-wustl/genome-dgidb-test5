package Genome::RefCov::ROI::BedLite;

use strict;
use warnings;

use Genome;


class Genome::RefCov::ROI::BedLite {
    has => [
        file => {
            is => 'String',
            doc => 'The file path of the defined regions/intervals',
        },
    ],
    has_optional => {
        wingspan => {
            is => 'Integer',
            doc => 'An integer distance to add to each end of a region.',
        },
        _fh => { },
        _chromosomes => { },
    }
};

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);
    my $fh = IO::File->new($self->file,'r');
    $self->_fh($fh);
    return $self;
}
sub chromosomes {
    my $self = shift;
    unless ($self->_chromosomes) {
        my $cmd = 'cut -f 1 '. $self->file .' | sort -u';
        my $output = `$cmd`;
        my @chromosomes = split("\n",$output);
        $self->_chromosomes(\@chromosomes);
    }
    return $self->_chromosomes;
}
sub next_region {
    my $self = shift;
    my $line = $self->_fh->getline;
    unless ($line) { $self->_fh->close; return; }

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
    $region{id} = $chr .':'. $start .'-'. $end;
    $region{length} = (($region{end} - $region{start}) + 1);
    #my $region = Genome::RefCov::ROI::Region->create(%region);
    return \%region;
}


1;
