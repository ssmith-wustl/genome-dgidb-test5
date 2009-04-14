#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";
use Genome::Model::Tools::Assembly::AutoJoin::ByCrossMatch;

use Test::More tests => 1;

ok(Genome::Model::Tools::Assembly::AutoJoin::ByCrossMatch->execute ( ace => 'autojoin_test.ace', dir => '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Assembly-Repair-AutoJoin/edit_dir') );
