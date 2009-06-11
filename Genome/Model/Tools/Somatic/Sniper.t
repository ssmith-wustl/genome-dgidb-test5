#!/gsc/bin/perl

use strict;
use warnings;

use File::Path;
use File::Temp;
use Test::More tests => 5;
use above 'Genome';

my $tumor =  "/gsc/var/cache/testsuite/data/Genome-Model-Tools-Somatic-Sniper/tumor.tiny.bam";
my $normal = "/gsc/var/cache/testsuite/data/Genome-Model-Tools-Somatic-Sniper/normal.tiny.bam";

my $tmpdir = File::Temp::tempdir('SomaticSniperXXXXX', DIR => '/gsc/var/cache/testsuite/running_testsuites/', CLEANUP => 0);
my $tmpfile = File::Temp->new( TEMPLATE=>'somatic_outputXXXXX', DIR=>$tmpdir, UNLINK=>0, SUFFIX=>'.txt'  );
my $output_file = $tmpfile->filename;

my $sniper = Genome::Model::Tools::Somatic::Sniper->create(tumor_file=>$tumor, normal_file=>$normal,  output_file=>$output_file);
ok($sniper, 'sniper command created');
my $rv = $sniper->execute;
is($rv, 1, 'Testing for successful execution.  Expecting 1.  Got: '.$rv);

$sniper = Genome::Model::Tools::Somatic::Sniper->create(tumor_file=>$tumor, normal_file=>$normal,  output_file=>$output_file);
ok($sniper, 'sniper command created');
$rv = $sniper->execute;
is($rv, 1, 'Testing for successful execution.  Expecting 1.  Got: '.$rv);

# Turned off software result for now in sniper
#ok(-e '/gscuser/adukes/svn/perl_modules/Genome/Model/Tools/Somatic/result_found', 'detected software result on second go round');
#unlink '/gscuser/adukes/svn/perl_modules/Genome/Model/Tools/Somatic/result_found';

my $length_test = 0;
if (length($output_file) > 70 ) {
    $length_test = 1 ;
} 
is($length_test,1,'Testing success: Expecting an output file >70. Got a string of length: '.length($output_file));
