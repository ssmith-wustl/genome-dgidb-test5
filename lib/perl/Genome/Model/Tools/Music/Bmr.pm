package Genome::Model::Tools::Music::Bmr;
use warnings;
use strict;
use Genome;

our $VERSION = $Genome::Model::Tools::Music::VERSION; 

class Genome::Model::Tools::Music::Bmr {
    is => 'Command::Tree',
    doc => "calculate gene coverages and background mutation rates"
};

1;
