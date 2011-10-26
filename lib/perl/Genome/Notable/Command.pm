package Genome::Notable::Command;

use strict;
use warnings;
use Genome;

class Genome::Notable::Command {
    is => 'Command::Tree',
    doc => 'work with notables',
};

# There are currently no un-hidden notable commands. Remove
# this when there are.
sub _is_hidden_in_docs {
    return 1;
}

1;

