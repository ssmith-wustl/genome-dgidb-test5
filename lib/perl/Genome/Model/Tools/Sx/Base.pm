package Genome::Model::Tools::Sx::Base;

use strict;
use warnings;

use Genome;            

class Genome::Model::Tools::Sx::Base {
};

#< Quality Calculation >#
sub calculate_average_quality {
    my ($self, $quality_string) = @_;
    Carp::confess('No quality string to calculate average.') if not defined $quality_string and not length $quality_string;
    my $total = 0;
    for my $q ( split('', $quality_string) ) {
        $total += ord($q) - 33;
    }
    return sprintf('%.0f', $total / length($quality_string));
}

sub calculate_qualities_over_minumum {
    my ($self, $quality_string, $min) = @_;
    Carp::confess('No quality string to calculate qualities over minimum.') if not defined $quality_string and not length $quality_string;
    Carp::confess('No minimum calculate qualities over minimum.') if not defined $min;
    my $total = 0;
    for my $q ( split('', $quality_string) ) {
        next if (ord($q) - 33) < $min;
        $total++;
    }
    return $total;
}
#<>#

1;

