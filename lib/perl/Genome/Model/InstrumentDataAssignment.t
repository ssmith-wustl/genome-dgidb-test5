#!/usr/bin/env perl

use strict;
use warnings;

use above "Genome";

use Test::More;

use_ok('Genome::Model::InstrumentDataAssignment') or die;

# Cannot directly create or delete this class see Genome::Model::Input
my $create = eval{ Genome::Model::InstrumentDataAssignment->create(); };
my $error = $@;
ok(!$create, 'cannot directly create IDA');
like($error, qr/^Genome::Model::InstrumentDataAssignment create must be called from Genome::Model::Input create/, 'error is correct');
my $delete = eval{ Genome::Model::InstrumentDataAssignment->delete(); };
$error = $@;
ok(!$delete, 'cannot directly delete IDA');
like($error, qr/^Genome::Model::InstrumentDataAssignment delete must be called from Genome::Model::Input delete/, 'error is correct');

done_testing();
exit;

