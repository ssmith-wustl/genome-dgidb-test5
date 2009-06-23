#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";
use Genome::ProcessingProfile::DeNovoAssembly::Test;

Genome::ProcessingProfile::DeNovoAssembly::Test->runtests;

exit;
