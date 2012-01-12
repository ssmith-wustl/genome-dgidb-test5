#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';

use Test::More;

use_ok('Genome::Model::Build::MetagenomicComposition16s::AmpliconSet') or die;

my $test_dir = '/gsc/var/cache/testsuite/data/Genome-Model/MetagenomicComposition16s454/build';
my $amplicon_set = Genome::Model::Build::MetagenomicComposition16s::AmpliconSet->create(
    name => '',
    primers => [qw/ c b a/],
    classification_dir => $test_dir.'/classification',
    classification_file => $test_dir.'/classification/H_GV-933124G-S.MOCK.V1_V3.rdp2-1',
    processed_fasta_file => $test_dir.'/fasta/H_GV-933124G-S.MOCK.V1_V3.processed.fasta',
    processed_qual_file => $test_dir.'/fasta/H_GV-933124G-S.MOCK.V1_V3.processed.fasta.qual',
    oriented_fasta_file => $test_dir.'/fasta/H_GV-933124G-S.MOCK.V1_V3.oriented.fasta',
);
ok($amplicon_set, 'Created amplicon set');
is($amplicon_set->name, '', 'Set name');
is_deeply([$amplicon_set->primers], [qw/ c b a/], 'Primers');
my $amplicon = $amplicon_set->next_amplicon;
ok($amplicon, 'Next amplicon');
is($amplicon->{name}, 'FZ0V7MM01A01AQ', 'Amplicon name');
ok($amplicon->{seq}, 'Amplicon seq');
ok($amplicon->{classification}, 'Amplicon classification');

done_testing();
exit;

