#!/usr/bin/env perl
use strict;
use warnings;
use above 'Genome';
use Genome::Model::Tools::Music;
use Test::More;

# figure out where the test inputs are and expected outputs
# the package with this data is a dependency so this should work
my $test_data_dir = Genome::Sys->dbpath('genome-music-test',$Genome::Model::Tools::Music::VERSION);
unless ($test_data_dir) {
    die "failed to find test data for genome-music-test version 0.01!";
}

#my $input_dir = '/gscuser/ndees/893/music_testdata/';
#my $expected_output_dir = '/gscuser/ndees/893/music_test_output/categ_clin/';
my $input_dir = $test_data_dir . '/inputs';
my $expected_output_dir = $test_data_dir . '/expected_outputs/categ_clin';

# decide where output goes
my $actual_output_dir;
if (@ARGV) {
    # override output dir
    if ($ARGV[0] eq '--regenerate') {
        # regenerate all output files as the new "correct" answer
        $actual_output_dir = $expected_output_dir;
    }
    else {
        # use the dir the user specifies (for dev testing)
        $actual_output_dir = shift @ARGV;
        mkdir $actual_output_dir unless -d $actual_output_dir;
        unless (-d $actual_output_dir) {
            die "failed to create directory $actual_output_dir: $!";
        }
    }
}
else {
    # by default use a temp dir
    $actual_output_dir= Genome::Sys->create_temp_directory("music");
};

# use cases and expected outputs
my @cases = (
    {
        run => "music clinical-correlation "
            . " --clinical-data-file $input_dir/clinical_data/tcga_OV_clinical_clean.csv.maf_samples.numeric.withNA.csv"
            . " --clinical-data-type numeric"
            . " --maf-file $input_dir/maf/tcga_ov_maf.csv.sample_name_shortened.somatic.nonsilent"
            . " --output-file $actual_output_dir/tcga_ov_maf.csv.sample_name_shortened.somatic.nonsilent.cat_cor.FIXME"
            . "  --genetic-data-type gene",
        expect => [
            'tcga_ov_maf.csv.sample_name_shortened.somatic.nonsilent.cat_cor.FIXME' 
        ]
    },
);

# pre-determine how many tests will run so the test harness knows if we exit early
my $tests = scalar(@cases) * 2;
for my $case (@cases) {
    my $expect = $case->{expect};
    unless ($expect) {
        warn "no files expected for test $case->{run}???";
        next;
    }
    $tests += (scalar(@$expect) * 2);
}

# since these tests don't run yet, and we don't want to stop deploy over it,
# require that an environment variable be set to actually run
plan tests => $tests;

# run each case
my $n = 0;
for my $case (@cases) {
    my $cmd = $case->{run};
    my $expect = $case->{expect};

    # execute
    my $n++;
    note("running test case $n: $cmd");
    my @args = split(' ',$cmd);
    my $exit_code = eval {
        Genome::Model::Tools->_execute_with_shell_params_and_return_exit_code(@args);
    };

    ok(!$@, " case $n ran without crashing") or diag $@;
    is($exit_code, 0, " case $n ran returned a zero (good) exit code") or next;

    # compare results
    for my $expect_file (@$expect) {
        my $expect_full_path = $expected_output_dir . '/'. $expect_file;
        my $actual_full_path = $actual_output_dir . '/' . $expect_file;
        
        ok(-e $actual_full_path, " case $n has expected output file $expect_file") or next;
        
        my @diff = `diff $expect_full_path $actual_full_path`;
        is(scalar(@diff), 0, " case $n matches expectations for file $expect_file")
            or diag("diff $expect_full_path and $actual_full_path; # << run this to debug"); 
    }
}


