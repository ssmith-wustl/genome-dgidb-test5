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

my $tumor =  "/gsc/var/cache/testsuite/data/Genome-Model-Tools-Somatic-Sniper/tumor.tiny.bam";
my $normal = "/gsc/var/cache/testsuite/data/Genome-Model-Tools-Somatic-Sniper/normal.tiny.bam";

my $tmpdir = File::Temp::tempdir('SomaticSniperXXXXX', DIR => '/gsc/var/cache/testsuite/running_testsuites/', CLEANUP => 1);
my $tmpfile_snp = File::Temp->new( TEMPLATE=>'somatic_outputXXXXX', DIR=>$tmpdir, UNLINK=>0, SUFFIX=>'.txt'  );
my $output_snp_file = $tmpfile_snp->filename;
my $tmpfile_indel = File::Temp->new( TEMPLATE=>'somatic_outputXXXXX', DIR=>$tmpdir, UNLINK=>0, SUFFIX=>'.txt'  );
my $output_indel_file = $tmpfile_indel->filename;

my $sniper = Genome::Model::Tools::Somatic::Sniper->create(tumor_bam_file=>$tumor, normal_bam_file=>$normal, output_snp_file=>$output_snp_file, output_indel_file=>$output_indel_file);
ok($sniper, 'sniper command created');
my $rv = $sniper->execute;
is($rv, 1, 'Testing for successful execution.  Expecting 1.  Got: '.$rv);

ok(-s $output_snp_file,'Testing success: Expecting a snp output file exists');
ok(-s $output_indel_file,'Testing success: Expecting a indel output file exists');
