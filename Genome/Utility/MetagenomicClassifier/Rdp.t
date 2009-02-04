#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";

use Genome::Utility::MetagenomicClassifier::Test;

Genome::Utility::MetagenomicClassifier::Rdp::Test->runtests;

exit;

#$HeadURL$
#$Id$
