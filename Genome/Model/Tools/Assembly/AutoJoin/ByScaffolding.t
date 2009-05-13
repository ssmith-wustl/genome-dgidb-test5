#!/gsc/bin/perl

use strict;
use warnings;

use File::Temp;
use above "Genome";
use Genome::Model::Tools::Assembly::AutoJoin::ByScaffolding;

use Test::More tests => 2;

my $test_dir = File::Temp::tempdir (CLEANUP => 1);

ok(Genome::Model::Tools::Assembly::AutoJoin->create_test_temp_dir ($test_dir));

ok(Genome::Model::Tools::Assembly::AutoJoin::ByScaffolding->execute ( ace => 'autojoin_test.ace', dir => $test_dir.'/edit_dir'));
