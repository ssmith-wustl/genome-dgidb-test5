#!/usr/bin/env perl

use strict;
use warnings;
use above 'Genome';
use Test::More tests => 3;

my $test_class = 'Genome::ProcessingProfile::Command::List';
use_ok($test_class);

my $expect = Genome::ProcessingProfile::Command::List::TestPipeline->create();
ok($expect, "made a command to list cases of the test pipeline");

ok($expect->execute(), "list executes");

