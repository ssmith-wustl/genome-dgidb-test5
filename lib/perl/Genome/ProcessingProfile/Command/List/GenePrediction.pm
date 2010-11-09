package Genome::ProcessingProfile::Command::List::GenePrediction;

use strict;
use warnings;
use Genome;

class Genome::ProcessingProfile::Command::List::GenePrediction {
    is => ['Genome::ProcessingProfile::Command::List', 'Command::DynamicSubCommands'],
};

sub _sub_commands_from { 'Genome::ProcessingProfile::GenePrediction' }

1;

