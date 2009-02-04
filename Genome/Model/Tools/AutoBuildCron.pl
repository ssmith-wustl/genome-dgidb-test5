#!/gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

my $results = Genome::Model::Tools::AutoBuild->execute();

1;