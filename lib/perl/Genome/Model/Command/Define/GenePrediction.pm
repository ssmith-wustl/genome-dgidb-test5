package Genome::Model::Command::Define::GenePrediction;

use strict;
use warnings;
use Genome;

# Command::DynamicSubCommands only applies to immediate subclasses to prevent
# any runaway behavior, which is why the redundant inheritance is needed here
class Genome::Model::Command::Define::GenePrediction {
    is => ['Genome::Model::Command::Define','Command::DynamicSubCommands'],
    is_abstract => 1,
};

sub _sub_commands_from { 'Genome::ProcessingProfile::GenePrediction' }

1;

