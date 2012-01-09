#!/usr/bin/env perl

use strict;
use warnings;

use above "Genome";

require File::Compare;
use Test::More;

use_ok('Genome::Model::Tools::Soap::Metrics') or die;

my $data_dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Soap/Metrics/v3';
my $example_metrics_file = $data_dir.'/metrics.txt';

my $temp_dir = Genome::Sys->create_temp_directory;
my $metrics_file = $temp_dir.'/metrics.txt';

my $metrics = Genome::Model::Tools::Soap::Metrics->create(
    assembly_directory => $data_dir,
    output_file => $metrics_file,
);
ok($metrics, "create") or die;
$metrics->dump_status_messages(1);
ok($metrics->execute, "execute") or die;
is(File::Compare::compare($metrics_file, $example_metrics_file), 0, "files match");

#print "gvimdiff $metrics_file $example_metrics_file\n"; system "gvimdiff $metrics_file $example_metrics_file"; <STDIN>;
done_testing();
exit;
