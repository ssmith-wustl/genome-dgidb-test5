#!/usr/bin/env perl

use strict;
use warnings;

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
};

use File::Path;
use File::Temp;
use File::Compare;
use Test::More;
use above 'Genome';
use Genome::SoftwareResult;

my $archos = `uname -a`;
if ($archos !~ /64/) {
    plan skip_all => "Must run from a 64-bit machine";
}
else {
    plan tests => 8;
}

use_ok('Genome::Model::Tools::DetectVariants2::GatkGermlineSnv');

# Override lock name because if people cancel tests locks don't get cleaned up.
*Genome::SoftwareResult::_resolve_lock_name = sub {
    return Genome::Sys->create_temp_file_path;
};


my $test_data = "/gsc/var/cache/testsuite/data/Genome-Model-Tools-DetectVariants2-GatkGermlineSnv";
my $expected_data = "/gsc/var/cache/testsuite/data/Genome-Model-Tools-DetectVariants2-GatkGermlineSnv/expected";
my $tumor =  $test_data."/flank_tumor_sorted.13_only.bam";

my $tmpbase = File::Temp::tempdir('GatkGermlineSnvXXXXX', DIR => '/gsc/var/cache/testsuite/running_testsuites/', CLEANUP => 1);
my $tmpdir = "$tmpbase/output";

my $refbuild_id = 101947881;

my $gatk_somatic_indel = Genome::Model::Tools::DetectVariants2::GatkGermlineSnv->create(
        aligned_reads_input=>$tumor, 
        reference_build_id => $refbuild_id,
        output_directory => $tmpdir, 
        mb_of_ram => 3000,
        version => 5336,
);

ok($gatk_somatic_indel, 'gatk_germline_snv command created');
my $rv = $gatk_somatic_indel->execute;
is($rv, 1, 'Testing for successful execution.  Expecting 1.  Got: '.$rv);

my @files = qw|     gatk_output_file
                    snvs.hq
                    snvs.hq.bed
                    snvs.hq.v1.bed
                    snvs.hq.v2.bed |;

for my $file (@files){
    my $expected_file = "$expected_data/$file";
    my $actual_file = "$tmpdir/$file";
    is(compare($actual_file,$expected_file),0,"Actual file is the same as the expected file: $file");
}
