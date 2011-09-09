#!/usr/bin/env perl

use strict;

use warnings;

use Test::More;
use File::Compare;

use above 'Genome';

if ($] < 5.010) {
  plan skip_all => "this test is only runnable on perl 5.10+"
}
plan tests => 4;

use_ok('Genome::Model::Tools::SmallRna::Spreadsheet');

my $tmp_dir = File::Temp::tempdir('SmallRna-Spreadsheet-'.Genome::Sys->username.'-XXXX',DIR => '/gsc/var/cache/testsuite/running_testsuites',CLEANUP => 1);
my $output_spreadsheet= $tmp_dir .'/spreadsheet.tsv';


my $data_dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-SmallRna-Spreadsheet';
my $expected_data_dir = $data_dir;

my $input_intersect_file = $data_dir .'/test_intersect.tsv';
my $input_stats_file = $data_dir .'/test_stats.tsv';

my $expected_spreadsheet = $expected_data_dir .'/test_spreadsheet.tsv';

my $spreadsheet = Genome::Model::Tools::SmallRna::Spreadsheet->create(
    input_intersect_file => 	$input_intersect_file,
    input_stats_file 	 => 	$input_stats_file,
    output_spreadsheet	 =>		$output_spreadsheet,    
);

isa_ok($spreadsheet,'Genome::Model::Tools::SmallRna::Spreadsheet');
ok($spreadsheet->execute,'execute Spreadsheet command '. $spreadsheet->command_name);
ok(!compare($expected_spreadsheet,$spreadsheet->output_spreadsheet),'expected spreadsheet file '. $expected_spreadsheet .' is identical to '. $spreadsheet->output_spreadsheet);


exit;

__END__
USAGE
 gmt5.12.1 small-rna spreadsheet --input-intersect-file=? --input-stats-file=?
    --output-spreadsheet=? [--input-cluster-number=?]

REQUIRED ARGUMENTS
  input-intersect-file   Text
    Input TSV file from annotate-cluster 
  input-stats-file   Text
    Input Statistics File from stats-generator 
  output-spreadsheet   Text
    Output speadsheet containing statistics as well as annotation for each cluster in the stats
    file 

OPTIONAL ARGUMENTS
  input-cluster-number   Text
    Number of TOP Clusters to calculate statistcs 
    Default value '5000' if not specified

DESCRIPTION
    These commands are setup to run perl5.12.1
