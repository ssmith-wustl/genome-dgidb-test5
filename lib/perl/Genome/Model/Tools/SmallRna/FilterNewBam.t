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

use_ok('Genome::Model::Tools::SmallRna::FilterNewBam');

my $tmp_dir = File::Temp::tempdir('SmallRna-FilterNewBam-'.Genome::Sys->username.'-XXXX',DIR => '/gsc/var/cache/testsuite/running_testsuites',CLEANUP => 1);
my $filtered_bam_file = $tmp_dir .'/test_filtered_71_73.bam';


my $data_dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-SmallRna-FilterNewBam';
my $expected_data_dir = $data_dir;

my $bam_file = $data_dir .'/test.bam';
my $read_size_bin   = '71_73';

my $expected_bam_file = $expected_data_dir .'/test_filtered_71_73.bam';

my $filter = Genome::Model::Tools::SmallRna::FilterNewBam->create(
    bam_file 			=> 		$bam_file,
    filtered_bam_file 	=> 		$filtered_bam_file,
    read_size_bin		=>		$read_size_bin,
    xa_tag				=>		1
    
);

isa_ok($filter,'Genome::Model::Tools::SmallRna::FilterNewBam');
ok($filter->execute,'execute FilterNewBam command '. $filter->command_name);
ok(!compare($expected_bam_file,$filter->filtered_bam_file),'expected annotation intersect file '. $expected_bam_file .' is identical to '. $filter->filtered_bam_file);


exit;

__END__

USAGE
 gmt5.12.1 small-rna filter-new-bam --bam-file=? --filtered-bam-file=?
    [--read-length-max=?] [--read-length-min=?] [--xa-tag]

REQUIRED ARGUMENTS
  bam-file   String
    Input BAM file of alignments. 
  filtered-bam-file   String
    Output BAM file of filtered read alignments . 

OPTIONAL ARGUMENTS
  read-length-max   String
    Maximum Read Length to filter the input bam on... Should be defined with read_length_min 
  read-length-min   String
    Minimum Read Length to filter the input bam on... Should be defined with read_length_max 
  xa-tag   Boolean
    Remove alignments where Map Score is 0 but no XA tag is reported 
  noxa-tag   Boolean
    Make xa-tag 'false' 

DESCRIPTION
 These commands are setup to run perl5.10.0 scripts that use Bio-Samtools and require bioperl
 v1.6.0.  Most require 64-bit architecture except those that simply work with output files from
 other Bio-Samtools commands.