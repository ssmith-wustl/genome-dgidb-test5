package Genome::ProcessingProfile::Command::Create::GenePrediction;

use strict;
use warnings;
use Genome;

class Genome::ProcessingProfile::Command::Create::GenePrediction {
    is => ['Genome::ProcessingProfile::Command::Create', 'Command::DynamicSubCommands'],
    is_abstract => 1,
};

sub _sub_commands_from { 'Genome::ProcessingProfile::GenePrediction' }

1;

