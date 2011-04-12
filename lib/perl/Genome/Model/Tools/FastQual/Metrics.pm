package Genome::Model::Tools::FastQual::Metrics;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';

class Genome::Model::Tools::FastQual::Metrics {
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

sub eval_seqs {
    my ($self, $seqs) = @_;

    for my $seq ( @$seqs ) {
        $self->_metrics->{bases} += length($seq->{seq});
        $self->_metrics->{count}++;
    }

    return 1;
}

1;

