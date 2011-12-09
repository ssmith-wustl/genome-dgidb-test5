#!/usr/bin/env perl

use strict;
use warnings;

use above "Genome";

require File::Compare;
use Test::More;

use_ok('Genome::Model::Tools::Soap::Metrics') or die;

my $data_dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Soap/Metrics';
my $example_metrics_file = $data_dir.'/stats.txt';

my $temp_dir = Genome::Sys->create_temp_directory();
Genome::Sys->create_directory($temp_dir.'/edit_dir');

foreach my $file_name (qw{ 1_fastq 2_fastq edit_dir/contigs.bases }) {
    my $file = $data_dir.'/'.$file_name;
    ok(-s $file, "test $file_name exists");
    my $link = $temp_dir.'/'.$file_name;
    symlink($data_dir."/$file_name", $link);
    ok(-s $link, "linked $file_name file to temp dir");
}

my $metrics = Genome::Model::Tools::Soap::Metrics->create(
    assembly_directory => $temp_dir,
);
ok($metrics, "create") or die;
$metrics->dump_status_messages(1);
ok($metrics->execute, "execute") or die;

my $metrics_file = $metrics->output_file;
is($metrics_file, $temp_dir.'/edit_dir/stats.txt', 'metrics file named correctly');
is(File::Compare::compare($metrics_file, $example_metrics_file), 0, "files match");

#print "gvimdiff $metrics_file $example_metrics_file\n"; <STDIN>;
done_testing();
exit;
