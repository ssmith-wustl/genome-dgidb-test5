#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';

use Genome::Model::Event::Build::ViromeScreen::Test;

Genome::Model::Event::Build::ViromeScreen::PrepareInstrumentDataTest->runtests;

exit (0);

