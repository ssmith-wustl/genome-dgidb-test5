package Genome::Model::Tools::DetectVariants2::Result;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::DetectVariants2::Result {
    is => ['Genome::Model::Tools::DetectVariants2::Result::Base'],
    doc => 'This class represents the result of a variant detector.',
};

#Most detector-specific logic is in Detector.pm

1;
