#!/usr/bin/env perl

use strict;
use warnings;

use above "Genome";
use Genome::ProcessingProfile::ViromeScreen::Test;

Genome::ProcessingProfile::ViromeScreen::Test->runtests;

exit;
