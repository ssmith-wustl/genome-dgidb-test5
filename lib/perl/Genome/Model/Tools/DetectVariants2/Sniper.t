#!/gsc/bin/perl

use strict;
use warnings;

use File::Path;
use File::Temp;
use Test::More;
use above 'Genome';

my $archos = `uname -a`;
if ($archos !~ /64/) {
    plan skip_all => "Must run from a 64-bit machine";
} else {
    plan tests => 6;
}

my $tumor =  "/gsc/var/cache/testsuite/data/Genome-Model-Tools-DetectVariants-Somatic-Sniper/tumor.tiny.bam";
my $normal = "/gsc/var/cache/testsuite/data/Genome-Model-Tools-DetectVariants-Somatic-Sniper/normal.tiny.bam";

my $tmpdir = File::Temp::tempdir('SomaticSniperXXXXX', DIR => '/gsc/var/cache/testsuite/running_testsuites/', CLEANUP => 1);

my $ref_seq_build = Genome::Model::Build::ImportedReferenceSequence->get(type_name => 'imported reference sequence', name => 'NCBI-human-build36');
ok($ref_seq_build, 'Got a reference sequence build') or die('Test cannot continue without a reference sequence build');
is($ref_seq_build->name, 'NCBI-human-build36', 'Got expected reference for test case');
my $ref_seq_input = $ref_seq_build->full_consensus_path('fa');

my $sniper = Genome::Model::Tools::DetectVariants2::Sniper->create(aligned_reads_input=>$tumor, 
                                                                   control_aligned_reads_input=>$normal,
                                                                   reference_sequence_input => $ref_seq_input,
                                                                   output_directory => $tmpdir, 
                                                                   version => '0.7.2',
                                                                   snv_params => '-q 1 -Q 15',
                                                                   indel_params => '-q 1 -Q 15');
ok($sniper, 'sniper command created');
my $rv = $sniper->execute;
is($rv, 1, 'Testing for successful execution.  Expecting 1.  Got: '.$rv);

my $output_snv_file = $sniper->output_directory . "/snvs.hq.bed";
my $output_indel_file = $sniper->output_directory . "/indels.hq.bed";

ok(-s $output_snv_file,'Testing success: Expecting a snv output file exists');
ok(-s $output_indel_file,'Testing success: Expecting a indel output file exists');
