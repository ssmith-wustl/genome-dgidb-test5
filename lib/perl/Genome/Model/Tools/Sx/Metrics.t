#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';

require File::Temp;
use Test::More;

use_ok('Genome::Model::Tools::Sx::Metrics') or die;

my $metrics = Genome::Model::Tools::Sx::Metrics->create();
ok($metrics, 'create');
ok($metrics->add_sequence({seq => 'AAGGCCTT',}), 'add seq');
is($metrics->count, 1, 'count');
is($metrics->bases, 8, 'bases');
ok($metrics->add_sequences([{seq => 'AAGGCCTT',}]), 'add seqs');
is($metrics->count, 2, 'count');
is($metrics->bases, 16, 'bases');

my $tmpdir = File::Temp::tempdir(CLEANUP => 1);
my $metrics_file = $tmpdir.'/metrics';
ok($metrics->write_to_file($metrics_file), 'write to file');
ok(-s $metrics_file, 'metrics file exists');
$metrics = Genome::Model::Tools::Sx::Metrics->read_from_file($metrics_file);
ok($metrics, 'read to file');
is_deeply({ bases => $metrics->bases, count => $metrics->count }, { bases => 16, count => 2 }, 'metrics write/read to file match');

done_testing();
exit;

