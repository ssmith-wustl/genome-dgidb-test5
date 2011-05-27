#!/usr/bin/env perl

use strict;
use warnings;

use above "Genome";
use Test::More;

use_ok( 'Genome::Model::Tools::Velvet::CreateGapFile' );
              
my $module = 'Genome-Model-Tools-Assembly-CreateOutputFiles2';
my $data_dir = "/gsc/var/cache/testsuite/data/$module";

ok(-d $data_dir, "Found data directory: $data_dir");

#test gap.txt file
#ok(-s $data_dir.'/edit_dir/gap.txt', "Found test gap.txt file");

my $test_contigs_file = $data_dir.'/contigs.fa';
ok(-s $test_contigs_file, "Found test contigs.fa file");

my $temp_dir = Genome::Sys->create_temp_directory();

#copy input file
ok(File::Copy::copy($test_contigs_file, $temp_dir),"Copied input contigs file");

#create, execute tool
my $create = Genome::Model::Tools::Velvet::CreateGapFile->create (
    assembly_directory => $temp_dir,
    );
ok( $create, "Created tool");
ok( $create->execute, "Successfully executed tool");

#test gap.txt file .. this file can be blank
my $test_gap_file = $data_dir.'/edit_dir/gap.txt';
ok(-e $test_gap_file, "Test gap.txt file exists");

#new gap.txt file
my $new_gap_file = $temp_dir.'/edit_dir/gap.txt';
ok(-e $new_gap_file, "New gap.txt file exits");

#diff
my @diffs = `sdiff -s $test_gap_file $new_gap_file`;
is(scalar (@diffs), 0, "New gap file matches test gap file");

done_testing();

exit;
