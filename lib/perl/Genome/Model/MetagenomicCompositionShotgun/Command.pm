use Genome;
use strict;
use warnings;

package Genome::Model::MetagenomicCompositionShotgun::Command;

class Genome::Model::MetagenomicCompositionShotgun::Command {
    is => 'Command',
    doc => 'operate on somatic models',
};

sub sub_command_category { 'type specific' }

1;

