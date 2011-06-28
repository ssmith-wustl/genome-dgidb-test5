package Genome::Sample::Command::Import;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';

class Genome::Sample::Command::Import {
    is_abstract => 1,
    is => 'Command',
};

sub help_brief {
    return 'Import samples';
}

1;

