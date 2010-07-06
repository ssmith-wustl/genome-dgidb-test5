#!/usr/bin/env perl
use strict;
use warnings;
use above "Genome";
use Test::More;

my $archos = `uname -a`;
if ($archos !~ /64/) {
    plan skip_all => "Must run from 64-bit machine";
}

# OLD:
# oneButtonVelvet-3opt.pl 1k-trimmed.fastq -i 260 -g 4500000 --hash 31 33 35 --version 0.7.57-64 -o old

# NEW:
# gmt velvet one-button 1k-trimmed.fastq -i 260 -g 4500000 --hash 31,33,35 --version 0.7.57-64 -o new
 
use Genome::Model::Tools::Velvet::OneButton;

my $module = 'Genome::Model::Tools::Velvet::OneButton';
#use_ok($module, "used $module without errors");

my @data_sub_dirs = ('v1-a', 'v1-b');#'v1-c');
my @params = ('-i 260 -g 4500000 --hash 31,33,35 --version 0.7.57-64 -o output-dir',
	      '-i 260 -g 4500000 --hash 31,33,35  --bound-enumeration 2 --version 0.7.57-64 -o output-dir');
	      #'-i 260 -g 4500000 --hash 31,33,35 --c 18,20,22 --bound-enumeration 2 --version 0.7.57-64 -o output-dir');

#last test param causes test to fail .. will check to make sure --c 18,20,22 are reasonible values before debugging
#make sure @data_sub_dirs and @params contain same # of elements

foreach my $param (@params) {

    my $data_dir = $module; 
    $data_dir =~ s/::/-/g;
    $data_dir = "/gsc/var/cache/testsuite/data/$data_dir";
    ok(-d $data_dir, "found data directory $data_dir");

    # CHANGE THIS WHENEVER WE INTENTIONALLY SWITCH OUTPUT 
    #$data_dir .= "/v1";
    my $data_sub_dir = '/'.shift @data_sub_dirs;
    $data_dir .= $data_sub_dir;

    my $expected_dir = $data_dir . '/output-dir';
    ok(-d $expected_dir, "found expected data directory $expected_dir");
    
    my $expected_stdout = $data_dir . '/actual.stdout';
    ok(-e $expected_stdout, "found expected data directory $expected_stdout");

    my $expected_stderr = $data_dir . '/actual.stderr';
    ok(-e $expected_stderr, "found expected data directory $expected_stderr");

    my $input_file = "$data_dir/input.fastq";
    ok(-e $input_file, "found input file $input_file");

    #my $temp_dir = Genome::Utility::FileSystem->create_temp_directory();
    # SWITCH TO THIS WHEN WE WANT TO GENERATE INTENTIONALLY NEW TEST DATA
    my $temp_dir = "/tmp/velvet$data_sub_dir"; 
    `mkdir -p $temp_dir`;
    ok(-d $temp_dir, "temp directory made at $temp_dir");

    my $actual_dir = "$temp_dir/output-dir";
    mkdir $actual_dir;
    ok(-d $actual_dir, "made output dir $actual_dir");

    my $actual_stdout = "$temp_dir/actual.stdout";
    my $actual_stderr = "$temp_dir/actual.stderr";

    my $cmd = "chdir $temp_dir; gmt velvet one-button $input_file $param > actual.stdout 2>actual.stderr";
    note($cmd);
    my $rv = system($cmd);
    $rv /= 256;
    ok($rv == 0, "command runs successfully");

    for my $old_file (glob("$actual_dir/*input.fastq*")) {
	use File::Basename;
	my $dirname = File::Basename::dirname($old_file);
	my $basename = File::Basename::basename($old_file);
	$basename =~ s/^.*input.fastq/SOMEDATE-input.fastq/;
	my $new_file = "$dirname/$basename"; 
	rename $old_file, $new_file;
	ok(-e $new_file, "renamed $old_file to $new_file");
    }

    my @dir_diff = `diff -r --brief $expected_dir $actual_dir | grep -v Log | grep -v timing`;
    
    #is(scalar(@dir_diff), 0, "directory contents match")
	#or diag(@dir_diff);
    
    print "@dir_diff\n";

    #my @stdout_diff = `sdiff -s $expected_stdout $actual_stdout | grep -v -- '$temp_dir'`;
    #is(scalar(@stdout_diff), 2, "stdout matches except for the line with a date")
	#or diag(@stdout_diff);

    my @stderr_diff = `sdiff -s $expected_stderr $actual_stderr | grep -v -- '$temp_dir'`;
    is(scalar(@stderr_diff), 0, "stderr matches except for the line with a date")
	or diag(@stderr_diff);

    # we skipped looking at the velvet log when diffing the whole dir b/c we know it has differences
    # now look at it specifically
    my @velvetlog_diff = `sdiff -s $expected_dir/*Log $actual_dir/*Log | grep -v -- '$temp_dir'`;
    is(scalar(@velvetlog_diff), 2, "the velvet log matches except the line with a date")
	or diag(@velvetlog_diff);
}

done_testing();

exit;


