package Genome::Model::Tools::Sx::Metrics;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';

class Genome::Model::Tools::Sx::Metrics {
    has => [
        count => { calculate_from => [qw/ _metrics /], calculate => q| return $_metrics->{count} |, },
        bases => { calculate_from => [qw/ _metrics /], calculate => q| return $_metrics->{bases} |, },
        _metrics => {
            is => 'Hash',
            is_optional => 1,
            default_value => {
                bases => 0, 
                count => 0,
            }, 
        },
    ],
};

sub add {
    my ($self, $seqs) = @_;

    for my $seq ( @$seqs ) {
        $self->_metrics->{bases} += length($seq->{seq});
        $self->_metrics->{count}++;
    }

    return 1;
}

sub to_string {
    my $self = shift;

    my $string;
    for my $metric (qw/ bases count /) {
        $string .= $metric.'='.$self->$metric."\n";
    }

    return $string;
}

1;

