package Genome::Model::Build::ImportedReferenceSequence;
use strict;
use warnings;
use Genome;

# all of the logic has been moved into a new class
# once fully stable, we will do a db update to flip the class names in the model/pp/build tables.

class Genome::Model::Build::ImportedReferenceSequence {
    is => 'Genome::Model::Build::ReferenceSequence',
};

1;

