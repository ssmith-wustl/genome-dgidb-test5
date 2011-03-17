#!/usr/bin/env perl
use strict;
use warnings;
use above 'Genome';
use Genome::Model::Tools::Music;
use Test::More;

# figure out where the test inputs are and expected outputs
# the package with this data is a dependency so this should work when deployed externally
my $test_data_dir = Genome::Sys->dbpath('genome-music-testdata',$Genome::Model::Tools::Music::VERSION);
unless ($test_data_dir) {
    plan skip_all => "failed to find test data for genome-music-testdata version $Genome::Model::Tools::Music::VERSION!";
}

my $input_dir = $test_data_dir . '/inputs';
my $expected_output_dir = $test_data_dir . '/expected_outputs/';

# decide where output goes...
my $actual_output_dir;
if (@ARGV) {
    # override output dir
    if ($ARGV[0] eq '--regenerate') {
        # regenerate all output files as the new "correct" answer
        $actual_output_dir = $expected_output_dir;
    }
    else {
        # use the dir the user specifies (for testing since tempdirs get destroyed)
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
        run => "music clinical-correlation \n"
            . " --clinical-data-file $input_dir/clinical_data/tcga_OV_clinical_clean.csv.maf_samples.numeric.withNA.csv \n"
            . " --clinical-data-type numeric \n"
            . " --maf-file $input_dir/maf/tcga_ov_maf.csv.sample_name_shortened.somatic.nonsilent \n"
            . " --output-file $actual_output_dir/num_clin/tcga_ov_maf.csv.sample_name_shortened.somatic.nonsilent.num_cor \n"
            . " --genetic-data-type gene",
        expect => [
            'num_clin/tcga_ov_maf.csv.sample_name_shortened.somatic.nonsilent.num_cor' 
        ],
    },
    {
        run => "music clinical-correlation\n"
          # . " --clinical-data-file $input_dir/clinical_data/tcga_OV_clinical_clean.csv.maf_samples.categorical.withNA.csv \n"
            . " --clinical-data-file $input_dir/clinical_data/tcga.categ.clin.data.vital.status \n"
            . " --clinical-data-type class \n"
            . " --maf-file $input_dir/maf/tcga.categ.clin.data.vital.status.maf \n"
            . " --output-file $actual_output_dir/categ_clin/tcga.categ.clin.data.vital.status.class_correlation \n"
            . " --genetic-data-type gene",
        expect => [
            'categ_clin/tcga.categ.clin.data.vital.status.class_correlation'
        ],
    },
    {
        run => "music cosmic-omim \n"
            . " --maf-file $input_dir/short.maf\n"
            . " --output-file $actual_output_dir/short_maf.cosmic_omim \n"
            . " --verbose 0",
        expect => [
            'short_maf.cosmic_omim'
        ],
    }, 
);

# pre-determine how many tests will run so the test harness knows if we exit early
my $tests = 0; 
for my $case (@cases) {
    next if $case->{skip};
    my $expect = $case->{expect};
    unless ($expect) {
        warn "no files expected for test $case->{run}???";
        next;
    }
    $tests += 2 + (scalar(@$expect) * 2);
}
plan tests => $tests;

# run each case
my $n = 0;
for my $case (@cases) {
    my $cmd = $case->{run};
    my $expect = $case->{expect};
    
    $n++;
    note("use case $n: $cmd");
    if (my $msg = $case->{skip}) {
        note "SKIPPING: $case->{skip}\n";
        next;
    }

    # make subdirs for the output if needed
    for my $expect_file (@$expect) {
        my $actual_full_path = $actual_output_dir . '/' . $expect_file;
        my $dir = $actual_full_path;
        use File::Basename;
        $dir = File::Basename::dirname($dir);
        Genome::Sys->create_directory($dir);
    }

    # execute
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
        
        my @diff = `diff -u $expect_full_path $actual_full_path`;
        my $diff_output;
        if (@diff > 20) {
            $diff_output = join("\n", @diff[0..19]) . "\ndiff output truncated.";
        }
        else {
            $diff_output = join("\n", @diff);
        }
        is(scalar(@diff), 0, " case $n matches expectations for file $expect_file")
            or diag("\$ diff $expect_full_path $actual_full_path\n" . $diff_output . "\n");
    }
}


