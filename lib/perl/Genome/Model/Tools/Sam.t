#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";
use Test::More tests => 4;

use_ok('Genome::Model::Tools::Sam');

my $sam = Genome::Model::Tools::Sam->create();

isa_ok($sam, 'Genome::Model::Tools::Sam');

# should get default versions since we do not specify
my $sam_version    = $sam->use_version();  
my $picard_version = $sam->use_picard_version();

ok(-e $sam->path_for_samtools_version($sam_version), "samtools version $sam_version exists");
ok(-e $sam->path_for_picard_version($picard_version), "picard version ($picard_version) exists");
