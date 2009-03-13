#!/usr/bin/env perl

use strict;
use warnings;

use above "Genome";

use Genome::Model::ReferenceAlignment::Report::Test;

Genome::Model::ReferenceAlignment::Report::GoldSnpTest->runtests;

exit;

#$HeadURL$
#$Id$
