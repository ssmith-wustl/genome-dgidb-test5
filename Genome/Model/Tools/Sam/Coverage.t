#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";

use Test::More tests => 5;
use File::Temp;
use File::Copy;
use File::Compare;

BEGIN {
    use_ok('Genome::Model::Tools::Sam::Coverage');
}

my $data_dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Sam-Coverage';
my $temp_path = '/gsc/var/cache/testsuite/running_testsuites/';

my $tmp_dir  = File::Temp::tempdir(
    "Coverage_XXXXXX", 
    DIR     => $temp_path,
    CLEANUP => 0,
);

my $pileup_file = "$data_dir/pileup.txt";
my $out_file = "$tmp_dir/coverage.out";

print "Input pileup file: $pileup_file\n";
print "Output file: $out_file\n";

my $coverage = Genome::Model::Tools::Sam::Coverage->create(
    pileup_file => $pileup_file,
    output_file => $out_file,                                                      
);

isa_ok($coverage,'Genome::Model::Tools::Sam::Coverage');
ok($coverage->execute,'executed ok');

my $coverage2 = Genome::Model::Tools::Sam::Coverage->create(
    pileup_file => $pileup_file,
);

my $result = $coverage2->execute;
#print "Result: \n".$result;
ok(defined($result),'return value defined');

$result =~ m/Average depth across all non-gap regions: (\S+)/g; 
my $haploid_coverage=$1 if defined($1);

ok( $haploid_coverage eq '10.4', "haploid coverage calculated correctly" );

#cmp_ok(compare($out_file, $ori_file), '==', 0, 'Sam SNPfilter file was created ok');

exit;

