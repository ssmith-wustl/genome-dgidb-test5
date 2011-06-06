package Genome::Model::Build::MetagenomicComposition16s::Sanger;

use strict;
use warnings;

use Genome;

use Carp 'confess';
use Data::Dumper 'Dumper';
require File::Copy;
use Finishing::Assembly::Factory;

class Genome::Model::Build::MetagenomicComposition16s::Sanger {
    is => 'Genome::Model::Build::MetagenomicComposition16s',
};

1;

