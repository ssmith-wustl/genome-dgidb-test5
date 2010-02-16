#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";
use Test::More tests => 3;

use_ok('Genome::Model::Tools::Picard');

my $picard = Genome::Model::Tools::Picard->create();

isa_ok($picard, 'Genome::Model::Tools::Picard');

# should get default versions since we do not specify
my $picard_version = $picard->use_version();
ok(-e $picard->path_for_picard_version($picard_version), "picard version ($picard_version) exists");

exit;
