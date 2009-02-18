#!/usr/bin/env perl

use strict;
use warnings;

use above "Genome";                         # >above< ensures YOUR copy is used during development
use Genome::Model::Tools::Assembly::Repair::AutoJoin;

use Test::More tests => 1;
use Storable;

my $indata = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Assembly-Repair-AutoJoin/edit_dir';

chdir($indata);
ok(Genome::Model::Tools::Assembly::Repair::AutoJoin->execute(ace => 'autojoin_test.ace'), 'successfully ran AutoJoins tool');


