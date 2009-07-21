#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";

use Test::More tests => 4;
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

my $compare_to_file = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Sam-Coverage/compare.txt';

my $aligned_file_name = "normal.tiny.bam"; 
my $output_file_name = "coverage.out";

my $ref_file = "/gscmnt/839/info/medseq/reference_sequences/NCBI-human-build36/all_sequences.fa";

my $aligned_file = $data_dir."/".$aligned_file_name;
my $output_file = $tmp_dir."/".$output_file_name;

print "Input aligned reads file: $aligned_file\n";
print "Ref file: $ref_file\n";
print "Output file: $output_file\n";

my $coverage = Genome::Model::Tools::Sam::Coverage->create(
    aligned_reads_file => $aligned_file,
    reference_file => $ref_file,
    output_file => $output_file,                                                      
    return_output => 1,
);

isa_ok($coverage,'Genome::Model::Tools::Sam::Coverage');
my $result = $coverage->execute;
$result =~ m/Average Coverage:(\S+)/g; 
my $haploid_coverage=$1 if defined($1);
ok( $haploid_coverage eq '223.681', "haploid coverage calculated correctly" );

cmp_ok(compare($output_file, $compare_to_file), '==', 0, 'Coverage output file create ok.');

#This test runs but has been commented out to save time in the test suite.
#my $coverage2 = Genome::Model::Tools::Sam::Coverage->create(
#    aligned_reads_file => $aligned_file,
#    reference_file => $ref_file,
#    return_output => 1,                                                     
#);

#my $result = $coverage2->execute;
#print "Result: \n".$result;
#ok(defined($result),'return value defined');

#old result string
#$result =~ m/Average depth across all non-gap regions: (\S+)/g; 

#$result =~ m/Average Coverage:(\S+)/g; 
#my $haploid_coverage=$1 if defined($1);

#ok( $haploid_coverage eq '223.681', "haploid coverage calculated correctly" );

exit;
