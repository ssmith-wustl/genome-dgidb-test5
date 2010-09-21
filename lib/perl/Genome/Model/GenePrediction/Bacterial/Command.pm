package Genome::Model::GenePrediction::Bacterial::Command;

use strict;
use warnings;

use Genome;

class Genome::Model::GenePrediction::Bacterial::Command {
    is => ['Command','Genome::Utility::FileSystem'],
    doc => "tools to work with gene prediction data sets",
};

1;

