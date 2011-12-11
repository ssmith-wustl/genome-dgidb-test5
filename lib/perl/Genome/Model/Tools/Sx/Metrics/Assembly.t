#!/usr/bin/env perl

use strict;
use warnings;

use above "Genome";

use Test::More;
require File::Compare;

use_ok('Genome::Model::Tools::Sx::Metrics::Assembly') or die;

#check testsuite data files
my $data_dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Soap/Stats_v1';
ok(-d $data_dir, "Data dir exists") or die;

#create temp test dir
my $temp_dir = Genome::Sys->create_temp_directory();
ok(-d $temp_dir, "Created temp test dir");

#copy files needed to run stats
foreach ('1_fastq', '2_fastq') {
    ok(File::Copy::copy($data_dir."/$_", $temp_dir), "Copied $_ file to temp dir");
    ok(-s $temp_dir."/$_", "Temp dir $_ file exists");
}
ok(File::Copy::copy($data_dir.'/contigs.bases', $temp_dir.'/edit_dir'), "Copied contigs.bases to temp edit_dir");

my $metrics = Genome::Model::Tools::Sx::Metrics::Assembly->create(
    major_contig_threshold => 300,
    tier_one => 3550,
    tier_two => 3550,
);
ok($metrics, "Created stats object") or die;
$metrics->add_contigs_file($data_dir.'/contigs.bases:type=fasta');
for my $reads_file ( $data_dir.'/1_fastq', $data_dir.'/2_fastq' ) {
    $metrics->add_reads_file($reads_file.':type=sanger');
}

my $text = $metrics->transform_xml_to('txt');
ok($text, 'got text');
my $metrics_file = $temp_dir.'/metrics.txt';
my $fh = Genome::Sys->open_file_for_writing($metrics_file);
$fh->print("$text");
$fh->close;

my $stats_file = $data_dir.'/stats.txt';
is(File::Compare::compare($metrics_file, $stats_file), 0, "files match");

#print "gvimdiff $metrics_file $stats_file\n"; <STDIN>;
done_testing();
exit;

