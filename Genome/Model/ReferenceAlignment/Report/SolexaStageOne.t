#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';

use Genome::Model::ReferenceAlignment::Report::Test;

Genome::Model::ReferenceAlignment::Report::SolexaStageOneTest->runtests;

exit;

#$HeadURL$
#$Id$
