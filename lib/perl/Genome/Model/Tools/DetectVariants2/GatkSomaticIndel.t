#!/gsc/bin/perl

use strict;
use warnings;

use File::Path;
use File::Temp;
use File::Compare;
use Test::More;
use above 'Genome';

my $archos = `uname -a`;
if ($archos !~ /64/) {
    plan skip_all => "Must run from a 64-bit machine";
}
else {
    plan tests => 7;
}

my $test_data = "/gsc/var/cache/testsuite/data/Genome-Model-Tools-DetectVariants2-GatkSomaticIndel";
my $expected_data = "/gsc/var/cache/testsuite/data/Genome-Model-Tools-DetectVariants2-GatkSomaticIndel/expected_3";
my $tumor =  $test_data."/flank_tumor_sorted.bam";
my $normal = $test_data."/flank_normal_sorted.bam";

my $tmpdir = File::Temp::tempdir('GatkSomaticIndelXXXXX', DIR => '/gsc/var/cache/testsuite/running_testsuites/', CLEANUP => 1);

my $refbuild_id = 101947881;

my $gatk_somatic_indel = Genome::Model::Tools::DetectVariants2::GatkSomaticIndel->create(
        aligned_reads_input=>$tumor, 
        control_aligned_reads_input=>$normal,
        reference_build_id => $refbuild_id,
        output_directory => $tmpdir, 
        mb_of_ram => 3500,
);

ok($gatk_somatic_indel, 'gatk_somatic_indel command created');
my $rv = $gatk_somatic_indel->execute;
is($rv, 1, 'Testing for successful execution.  Expecting 1.  Got: '.$rv);

my @files = qw|     gatk_output_file
                    indels.hq
                    indels.hq.bed
                    indels.hq.v1.bed
                    indels.hq.v2.bed |;

for my $file (@files){
    my $expected_file = "$expected_data/$file";
    my $actual_file = "$tmpdir/$file";
    is(compare($actual_file,$expected_file),0,"Actual file is the same as the expected file: $file");
}
