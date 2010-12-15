package Genome::Model::ImportedReferenceSequence;
use strict;
use warnings;
use Genome;

# all of the logic has been moved into a new class
# once fully stable, we will do a db update to flip the class names in the model/pp/build tables.

class Genome::Model::ImportedReferenceSequence {
    is => 'Genome::Model::ReferenceSequence',
};

1;

