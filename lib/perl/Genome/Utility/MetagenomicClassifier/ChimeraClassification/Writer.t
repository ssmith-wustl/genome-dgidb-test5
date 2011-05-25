#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';

use Genome::Utility::MetagenomicClassifier::Test;

Genome::Utility::MetagenomicClassifier::ChimeraClassification::Writer::Test->runtests;

exit;

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/trunk/Genome/Utility/MetagenomicClassifier/Rdp/Writer.t $
#$Id: Writer.t 43284 2009-02-04 22:15:30Z ebelter $
