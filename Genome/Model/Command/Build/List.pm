package Genome::Model::Command::Build::List;
use strict;
use warnings;

# The lister for builds lives in the 'normal' place.
# Once we move all of these commands over to that tree, 
# the "genome model build" tree will be entierely redirected
# there like the metric tree.

class Genome::Model::Command::Build::List {
    is => 'Genome::Model::Build::Command::List'
};

1;

