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
    plan tests => 9;
}

my $test_data = "/gsc/var/cache/testsuite/data/Genome-Model-Tools-DetectVariants2-GatkSomaticIndel";
my $expected_data = "/gsc/var/cache/testsuite/data/Genome-Model-Tools-DetectVariants2-GatkSomaticIndel/expected";
my $tumor =  $test_data."/flank_tumor_sorted.bam";
my $normal = $test_data."/flank_normal_sorted.bam";

my $tmpdir = File::Temp::tempdir('GatkSomaticIndelXXXXX', DIR => '/gsc/var/cache/testsuite/running_testsuites/', CLEANUP => 1);

my $ref_seq_build = Genome::Model::Build::ImportedReferenceSequence->get(type_name => 'imported reference sequence', name => 'NCBI-human-build36');
ok($ref_seq_build, 'Got a reference sequence build') or die('Test cannot continue without a reference sequence build');
is($ref_seq_build->name, 'NCBI-human-build36', 'Got expected reference for test case');
my $ref_seq_input = $ref_seq_build->full_consensus_path('fa');
# temporary hack - use the network disk instead of the cache since the sequence dictionary was changed and this update was not propagated to all blades. Change this once this problem is solved - gsanders
$ref_seq_input =~ s/\/opt\/fscache//;

my $gatk_somatic_indel = Genome::Model::Tools::DetectVariants2::GatkSomaticIndel->create(
        aligned_reads_input=>$tumor, 
        control_aligned_reads_input=>$normal,
        reference_sequence_input => $ref_seq_input,
        output_directory => $tmpdir, 
        mb_of_ram => 3000,
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
