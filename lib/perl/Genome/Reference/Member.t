#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 6;

use above 'Genome';

BEGIN {
        use_ok('Genome::Reference::Member');
}
my $member = Genome::Reference::Member->get(
                                            seq_id => 2732768307,
                                            member_seq_id => 1676113890
                                        );
isa_ok($member,'Genome::Reference::Member');

my $reference = $member->reference;
isa_ok($reference,'Genome::Reference');

is($member->sequence_item_name,'NCBI-human-build36-chrom1','got sequence_item_name');
is($member->sequence_item_type,'chromosome sequence','got sequence_item_type');
is($member->seq_length,247249719,'got seq_length');
exit;
