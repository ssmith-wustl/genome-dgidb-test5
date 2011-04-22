#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Test::More;

use_ok('Genome::Model::Tools::FastQual::Metrics') or die;

my $metrics = Genome::Model::Tools::FastQual::Metrics->create();
ok($metrics, 'create');
ok($metrics->add([{seq => 'AAGGCCTT',}]), 'eval seqs');
is($metrics->count, 1, 'count');
is($metrics->bases, 8, 'bases');
ok($metrics->add([{seq => 'AAGGCCTT',}]), 'eval seqs');
is($metrics->count, 2, 'count');
is($metrics->bases, 16, 'bases');

done_testing();
exit;

