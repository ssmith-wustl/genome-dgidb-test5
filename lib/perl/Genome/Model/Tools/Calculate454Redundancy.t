#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';
use Test::More;

#minimally testing things tool needs to run .. will add full test later

use_ok('Genome::Model::Tools::Calculate454Redundancy');

ok (-x '/gscmnt/temp224/research/lye/rd454_mapasm_08172010/applicationsBin/runAssembly', "Default version of newbler exists");

ok (-x '/gscmnt/233/info/seqana/scripts/BLADE_CROSSMATCH_for_454_redundancy.pl', "Cross jobs dispatcher exists");



done_testing();

exit;
