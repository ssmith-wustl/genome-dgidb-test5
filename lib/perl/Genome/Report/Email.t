#!/usr/bin/env perl

use strict;
use warnings;

use above "Genome";

use Genome::Report::Test;

Genome::Report::Email::Test->runtests;

exit;

#$HeadURL$
#$Id$
