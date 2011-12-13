#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';

require File::Temp;
use Test::More;

use_ok('Genome::Model::Tools::Sx::Metrics::Basic') or die;

my $metrics = Genome::Model::Tools::Sx::Metrics::Basic->create();
ok($metrics, 'create');
ok($metrics->add_sequence({seq => 'AAGGCCTT',}), 'add seq');
my $metrics_obj = $metrics->metrics;
is($metrics_obj->count, 1, 'count');
is($metrics_obj->bases, 8, 'bases');
ok($metrics->add_sequences([{seq => 'AAGGCCTT',}]), 'add seqs');
$metrics_obj = $metrics->metrics;
is($metrics_obj->count, 2, 'count');
is($metrics_obj->bases, 16, 'bases');

my $tmpdir = File::Temp::tempdir(CLEANUP => 1);
my $file = $tmpdir.'/metrics';
ok($metrics->to_file($file), 'to file');
ok(-s $file, 'metrics file exists');
$metrics = Genome::Model::Tools::Sx::Metrics::Basic->from_file($file);
ok($metrics, 'from file');
$metrics_obj = $metrics->metrics;
is_deeply({ bases => $metrics_obj->bases, count => $metrics_obj->count }, { bases => 16, count => 2 }, 'metrics write/read to file match');

done_testing();
exit;

