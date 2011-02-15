#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";

use Test::More;

use_ok('Genome::Model::InstrumentDataAssignment') or die;

# Cannot directly create or delete this class see Genome::Model::Input
my $create = eval{ Genome::Model::InstrumentDataAssignment->create(); };
ok(!$create, 'cannot directly create IDA');
my $delete = eval{ Genome::Model::InstrumentDataAssignment->delete(); };
ok(!$delete, 'cannot directly delete IDA');

done_testing();
exit;

