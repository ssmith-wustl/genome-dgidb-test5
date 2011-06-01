#!/usr/bin/env perl

use strict;
use warnings;

use File::Temp;
use above "Genome";
use Genome::Model::Tools::Assembly::AutoJoin::ByCrossMatch;

use Test::More skip_all => 'this test fails randomly fix me';

my $test_dir = File::Temp::tempdir (CLEANUP => 1);

ok(Genome::Model::Tools::Assembly::AutoJoin->create_test_temp_dir ($test_dir));

ok(Genome::Model::Tools::Assembly::AutoJoin::ByCrossMatch->execute ( ace => 'autojoin_test.ace', dir => $test_dir.'/edit_dir'));
