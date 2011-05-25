#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';

use Genome::Utility::MetagenomicClassifier::Test;

Genome::Utility::MetagenomicClassifier::Rdp::Reader::Test->runtests;

exit;

#$HeadURL$
#$Id$
