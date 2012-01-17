#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';

use Test::More;

use_ok('Genome::Model::Build::MetagenomicComposition16s::AmpliconSet') or die;

my $test_dir = '/gsc/var/cache/testsuite/data/Genome-Model/MetagenomicComposition16s454/build';
my $file_base_name = 'H_GV-933124G-S.MOCK';
my $amplicon_set = Genome::Model::Build::MetagenomicComposition16s::AmpliconSet->create(
    name => 'V1_V3',
    primers => [qw/ c b a/],
    file_base_name => $file_base_name,
    directory => $test_dir,
    classification_dir => $test_dir.'/classification',
    classification_file => $test_dir.'/classification/H_GV-933124G-S.MOCK.V1_V3.rdp2-1',
    oriented_fasta_file => $test_dir.'/fasta/H_GV-933124G-S.MOCK.V1_V3.oriented.fasta',
);
ok($amplicon_set, 'Created amplicon set');
is($amplicon_set->name, 'V1_V3', 'Set name');
is_deeply([$amplicon_set->primers], [qw/ c b a/], 'Primers');
is($amplicon_set->file_base_name, 'H_GV-933124G-S.MOCK', 'file base name');
is($amplicon_set->fasta_dir, $test_dir.'/fasta', 'fasta dir base name');
is($amplicon_set->processed_fasta_file, $test_dir.'/fasta/'.$file_base_name.'.V1_V3.processed.fasta', 'Process fasta file name');
is($amplicon_set->processed_qual_file, $test_dir.'/fasta/'.$file_base_name.'.V1_V3.processed.fasta.qual', 'Process qual file name');
my $amplicon = $amplicon_set->next_amplicon;
ok($amplicon, 'Next amplicon');
is($amplicon->{name}, 'FZ0V7MM01A01AQ', 'Amplicon name');
ok($amplicon->{seq}, 'Amplicon seq');
ok($amplicon->{classification}, 'Amplicon classification');

done_testing();
exit;

