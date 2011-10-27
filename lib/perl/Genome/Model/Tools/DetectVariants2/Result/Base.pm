package Genome::Model::Tools::DetectVariants2::Result::Base;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::DetectVariants2::Result::Base {
    is => ['Genome::SoftwareResult::Stageable'],
    is_abstract => 1,
    doc => 'This class represents the result of a detect-variants operation. This base class just unites the various result types',
};

1;
