#!/gsc/bin/perl

use strict;
use warnings;

use File::Path;
use File::Temp;
use Test::More;
#use Test::More skip_all => 'due to taking model ids as input now we have to mock models to test this, and havnt done so yet';
use above 'Genome';

my $archos = `uname -a`;
if ($archos !~ /64/) {
    plan skip_all => "Must run from 64-bit machine";
} else {
    plan tests => 4;
}

my $tumor =  "/gsc/var/cache/testsuite/data/Genome-Model-Tools-DetectVariants-Somatic-Sniper/tumor.tiny.bam";
my $normal = "/gsc/var/cache/testsuite/data/Genome-Model-Tools-DetectVariants-Somatic-Sniper/normal.tiny.bam";

my $tmpdir = File::Temp::tempdir('SomaticSniperXXXXX', DIR => '/gsc/var/cache/testsuite/running_testsuites/', CLEANUP => 1);

my $sniper = Genome::Model::Tools::DetectVariants2::Somatic::Sniper->create(aligned_reads_input=>$tumor, control_aligned_reads_input=>$normal, output_directory => $tmpdir, version => '0.7.2');
ok($sniper, 'sniper command created');
my $rv = $sniper->execute;
is($rv, 1, 'Testing for successful execution.  Expecting 1.  Got: '.$rv);

my $output_snp_file = $sniper->snv_output;
my $output_indel_file = $sniper->indel_output;

ok(-s $output_snp_file,'Testing success: Expecting a snp output file exists');
ok(-s $output_indel_file,'Testing success: Expecting a indel output file exists');
