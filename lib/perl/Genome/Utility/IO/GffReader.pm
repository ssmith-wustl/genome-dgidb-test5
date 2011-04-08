package Genome::Utility::IO::GffReader;

use strict;
use warnings;

use Genome;

my @DEFAULT_HEADERS = qw/chr source type start end score strand frame attributes/;

class Genome::Utility::IO::GffReader {
    is => ['Genome::Utility::IO::SeparatedValueReader'],
    has => [
        ignore_lines_starting_with => {
            default_value => '##',
        },
        separator => {
            default_value => "\t",
        },
    ],
};

sub headers {
    return \@DEFAULT_HEADERS;
}

sub create {
    my $class = shift;
    my %params = @_;

    my $headers = delete $params{headers};
    unless ($headers) {
        $headers = $class->headers;
    }
    $params{headers} = $headers;
    my $self = $class->SUPER::create(%params)
        or return;
    return $self;
}


1;
