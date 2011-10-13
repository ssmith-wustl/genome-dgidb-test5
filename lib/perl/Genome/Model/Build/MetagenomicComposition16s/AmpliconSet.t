#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';

use Test::More;

my $class = 'Genome::Model::Build::MetagenomicComposition16s::AmpliconSet';
use_ok($class);

my $amplicon_set = $class->create(
    name => '',
    amplicon_iterator => sub{ return 1; },
    classification_dir => 'dir',
    classification_file => 'file',
    processed_fasta_file => 'file',
    oriented_fasta_file => 'file',
);
ok($amplicon_set, 'Created amplicon set');
is($amplicon_set->name, '', 'Set name');
ok($amplicon_set->next_amplicon, 'Next amplicon');

done_testing();
exit;

