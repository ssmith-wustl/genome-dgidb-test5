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

use_ok('Genome::Model::Tools::SmallRna::AnnotateCluster');

my $tmp_dir = File::Temp::tempdir('SmallRna-AnnotateCluster-'.Genome::Sys->username.'-XXXX',DIR => '/gsc/var/cache/testsuite/running_testsuites',CLEANUP => 1);
my $output_tsv_file = $tmp_dir .'/test_annotation_intersect.tsv';


my $data_dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-SmallRna-AnnotateCluster';
my $expected_data_dir = $data_dir;

my $annotation_bed_file = $data_dir .'/test1.bed,'.$data_dir.'/test2.bed';
my $annotation_name = 'test1,test2';
my $cluster_bed_file = $data_dir .'/test_clusters.bed';

my $expected_output_tsv_file = $expected_data_dir .'/test_annotation_intersect.tsv';

my $annotate = Genome::Model::Tools::SmallRna::AnnotateCluster->create(
    annotation_bed_file => 		$annotation_bed_file,
    annotation_name 	=> 		$annotation_name,
    output_tsv_file		=>		$output_tsv_file,
    cluster_bed_file	=>		$cluster_bed_file,
    
);

isa_ok($annotate,'Genome::Model::Tools::SmallRna::AnnotateCluster');
ok($annotate->execute,'execute AnnotateCluster command '. $annotate->command_name);
ok(!compare($expected_output_tsv_file,$annotate->output_tsv_file),'expected annotation intersect file '. $expected_output_tsv_file .' is identical to '. $annotate->output_tsv_file);


exit;

__END__
USAGE
 gmt5.12.1 small-rna annotate-cluster --annotation-bed-file=? --annotation-name=?
    --cluster-bed-file=? --output-tsv-file=?

REQUIRED ARGUMENTS
  annotation-bed-file   String
    Input BED file containing annotation,For more than one, supply a comma delimited list 
  annotation-name   String
    Comma delimited list of the Annotation Tracks. Should be in the same order as the list of
    annotation bed files. 
  cluster-bed-file   Text
    Input top N clusters BED file from Stats-Generator 
  output-tsv-file   Text
    Raw Output file from Intersectbed 

DESCRIPTION
    These commands are setup to run perl5.12.1
