#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Genome::Utility::MetagenomicClassifier::Test;

Genome::Utility::MetagenomicClassifier::Rdp::Writer::Test->runtests;

exit;

#$HeadURL$
#$Id$
