package Genome::Model::Tools::RefCov::RnaSeq;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::RefCov::RnaSeq {
    is => ['Genome::Model::Tools::RefCov'],
    has => [

    ],
};

sub execute {
    my $self = shift;
    unless ($] > 5.012) {
        die "Bio::DB::Sam requires perl 5.12!";
    }
    require Bio::DB::Sam;
    return 1;
}

1;
