#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';

use Storable qw/ retrieve /;
use Test::More;

use_ok('Genome::Utility::MetagenomicClassifier::Rdp::Reader') or die;
use_ok('Genome::Utility::MetagenomicClassifier') or die;
use_ok('Genome::Utility::MetagenomicClassifier::SequenceClassification') or die;

my $reader = Genome::Utility::MetagenomicClassifier::Rdp::Reader->create(
    input => '/gsc/var/cache/testsuite/data/Genome-Utility-MetagenomicClassifier/U_PR-JP_TS1_2PCA.fasta.rdp',
);
ok($reader, 'create rdp reader');
my @classifications = $reader->all;
ok(@classifications, 'Got classifications from reader');
my $expected_classifications = retrieve('/gsc/var/cache/testsuite/data/Genome-Utility-MetagenomicClassifier/classifications.stor');
is_deeply(\@classifications, $expected_classifications, 'Generated and exclassifications.storpected classification objects match');

done_testing();
exit;

