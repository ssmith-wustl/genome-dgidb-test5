package Genome::ProcessingProfile::Command::Create::GenePrediction;

use strict;
use warnings;
use Genome;

class Genome::ProcessingProfile::Command::Create::GenePrediction {
    is => ['Genome::ProcessingProfile::Command::Create'],
    doc => 'Create a new profile for gene prediction',
};

sub _sub_commands_from { 'Genome::ProcessingProfile::GenePrediction' };
sub _target_base_class { 'Genome::ProcessingProfile::GenePrediction' };

1;

