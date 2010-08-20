package Genome::Model::BacterialGeneAnnotation::Command;

use strict;
use warnings;

use Genome;

class Genome::Model::BacterialGeneAnnotation::Command {
    is => ['Command','Genome::Utility::FileSystem'],
    doc => "tools to work with gene prediction data sets",
};

1;

