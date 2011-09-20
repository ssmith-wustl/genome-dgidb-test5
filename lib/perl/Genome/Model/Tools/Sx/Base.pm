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
#<>#

1;

