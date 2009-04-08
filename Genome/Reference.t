#!/gsc/bin/perl

use strict;
use warnings;

use Test::More tests => 8;

use above 'Genome';

BEGIN {
      use_ok('Genome::Reference');
      use_ok('Genome::Reference::Member');
}

my $ref_set = Genome::Reference->get(2774911462);
isa_ok($ref_set,'Genome::Reference');

my $gsc_ref_set = $ref_set->gsc_reference_set;
isa_ok($gsc_ref_set,'GSC::Sequence::ReferenceSet');

my $bfa_dir = $ref_set->bfa_directory;
is($bfa_dir,'/gsc/var/lib/reference/set/2774911462/maq_binary_fasta','got expected bfa directory');

ok(-e $bfa_dir .'/ALL.bfa','bfa file '. $bfa_dir.'/ALL.bfa exists');
ok(-s $bfa_dir .'/ALL.bfa','bfa file '. $bfa_dir .'/ALL.bfa has size');


my $human_ref_set = Genome::Reference->get(2732768307);
my @members = $human_ref_set->members;
is(scalar(@members),27,'found 27 members of human reference set');

exit;
