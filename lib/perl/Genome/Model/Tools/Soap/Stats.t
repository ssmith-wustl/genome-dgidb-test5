#!/usr/bin/env perl

use strict;
use warnings;

use above "Genome";
use Test::More;
require File::Compare;

use_ok('Genome::Model::Tools::Soap::Stats') or die;

#check testsuite data files
my $data_dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Soap/Stats_v1';
ok(-d $data_dir, "Data dir exists") or die;
ok(-s $data_dir.'/contigs.bases', "Data dir contigs.bases file exists") or die;
ok(-s $data_dir.'/1_fastq', "Data dir 1_fastq file exists") or die;
ok(-s $data_dir.'/2_fastq', "Data dir 2_fastq file exists") or die;
ok(-s $data_dir.'/stats.txt', "Data dir example stats file exists") or die;

#create temp test dir
my $temp_dir = Genome::Sys->create_temp_directory();
ok(-d $temp_dir, "Created temp test dir");
mkdir $temp_dir.'/edit_dir';
ok(-d $temp_dir.'/edit_dir', "Created temp dir edit_dir");

#copy files needed to run stats
foreach ('1_fastq', '2_fastq') {
    ok(File::Copy::copy($data_dir."/$_", $temp_dir), "Copied $_ file to temp dir");
    ok(-s $temp_dir."/$_", "Temp dir $_ file exists");
}
ok(File::Copy::copy($data_dir.'/contigs.bases', $temp_dir.'/edit_dir'), "Copied contigs.bases to temp edit_dir");

#create, execute tool
my $stats = Genome::Model::Tools::Soap::Stats->create(
    assembly_directory => $temp_dir,
    );
ok($stats, "Created stats object") or die;
ok(($stats->execute) == 1, "Executed stats successfully") or die;

#compare files
ok(-s $temp_dir.'/edit_dir/stats.txt', "Stats file created in temp edit_dir") or die;
ok(File::Compare::compare($temp_dir.'/edit_dir/stats.txt', $data_dir.'/stats.txt') == 0, "Stats files match");

#<STDIN>;

done_testing();

exit;
