#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";

use Test::More tests => 2;
use Genome::Utility::PSL::Reader;
my $file = 'test.psl';
my $reader = Genome::Utility::PSL::Reader->create(
                                                   file => $file,
                                               );
isa_ok($reader,'Genome::Utility::PSL::Reader');
ok($reader->execute,'execute');

exit;
