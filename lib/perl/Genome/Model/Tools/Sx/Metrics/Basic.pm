package Genome::Model::Tools::Sx::Metrics::Basic;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::Sx::Metrics::Basic {
    is => 'Genome::Model::Tools::Sx::Metrics::Base',
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

class Sx::Metrics::Basic {
    has => [
        bases => { is => 'Number', }, 
        count => { is => 'Number', }, 
    ],
};

sub add_sequence {
    my ($self, $seq) = @_;

    $self->_metrics->{bases} += length($seq->{seq});
    $self->_metrics->{count}++;

    return 1;
}

sub add_sequences {
    my ($self, $seqs) = @_;

    for my $seq ( @$seqs ) {
        $self->add_sequence($seq);
    }

    return 1;
}

1;

