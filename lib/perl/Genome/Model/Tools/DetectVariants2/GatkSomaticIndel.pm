package Genome::Model::Tools::DetectVariants2::GatkSomaticIndel;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::DetectVariants2::GatkSomaticIndel{
    is => ['Genome::Model::Tools::DetectVariants2::Detector'],
};

sub _detect_variants {
    my $self = shift;

    die "not yet implemented\n";

    return 1;
}

sub has_version {
    return 1; #FIXME implement this when this module is filled out
}

1;
