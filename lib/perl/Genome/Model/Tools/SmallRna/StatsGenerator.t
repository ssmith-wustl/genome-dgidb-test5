#!/usr/bin/env perl

use strict;

use warnings;

use Test::More;
use File::Compare;

use above 'Genome';

if ($] < 5.010) {
  plan skip_all => "this test is only runnable on perl 5.10+"
}
plan tests => 7;

use_ok('Genome::Model::Tools::SmallRna::StatsGenerator');

my $tmp_dir = File::Temp::tempdir('SmallRna-StatsGenerator-'.Genome::Sys->username.'-XXXX',DIR => '/gsc/var/cache/testsuite/running_testsuites',CLEANUP => 1);
my $output_clusters_file = $tmp_dir .'/test_top_sorted_clusters.bed';
my $output_stats_file 	  = $tmp_dir .'/test_alignment_stats.tsv';
my $output_subcluster_intersect_file = $tmp_dir .'/test_subclusters_intersect.tsv';
my $output_subclusters_file = $tmp_dir .'/test_subclusters.bed';

my $data_dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-SmallRna-StatsGenerator';
my $expected_data_dir = $data_dir;

my $bam_file_path = $data_dir .'/test.bam';
my $coverage_stats_file = $data_dir .'/test_coverage.stats';

my $expected_output_clusters_file = $expected_data_dir .'/test_top_sorted_clusters.bed';
my $expected_output_stats_file 	  = $expected_data_dir .'/test_alignment_stats.tsv';
my $expected_output_subcluster_intersect_file = $expected_data_dir .'/test_subclusters_intersect.tsv';
my $expected_output_subclusters_file = $expected_data_dir .'/test_subclusters.bed';



my $stats_gen = Genome::Model::Tools::SmallRna::StatsGenerator->create(
    bam_file => $bam_file_path,
    coverage_stats_file => $coverage_stats_file,
    output_clusters_file=>$output_clusters_file,
    output_stats_file=>$output_stats_file,
    output_subcluster_intersect_file =>$output_subcluster_intersect_file,
    output_subclusters_file =>$output_subclusters_file,
);

isa_ok($stats_gen,'Genome::Model::Tools::SmallRna::StatsGenerator');
ok($stats_gen->execute,'execute StatsGenerator command '. $stats_gen->command_name);

ok(!compare($expected_output_clusters_file,$stats_gen->output_clusters_file),'expected clusters file '. $expected_output_clusters_file .' is identical to '. $stats_gen->output_clusters_file);
ok(!compare($expected_output_stats_file,$stats_gen->output_stats_file),'expected alignment stats file '. $expected_output_stats_file .' is identical to '. $stats_gen->output_stats_file);
ok(!compare($expected_output_subcluster_intersect_file,$stats_gen->output_subcluster_intersect_file),'expected subclusters intersect file '. $expected_output_subcluster_intersect_file .' is identical to '. $stats_gen->output_subcluster_intersect_file);
ok(!compare($expected_output_subclusters_file,$stats_gen->output_subclusters_file),'expected subclusters file '. $expected_output_subclusters_file .' is identical to '. $stats_gen->output_subclusters_file);


exit;

__END__
USAGE
 gmt5.12.1 small-rna stats-generator --bam-file=? --coverage-stats-file=?
    --output-clusters-file=? --output-stats-file=? --output-subcluster-intersect-file=?
    --output-subclusters-file=? --subcluster-min-mapzero=?

REQUIRED ARGUMENTS
  bam-file   Text
    Input BAM file of alignments 
  coverage-stats-file   Text
    Input stats file from ClusterCoverage 
  output-clusters-file   Text
    Output BED file containing coordinates of clusters in BED format (sorted by depth) 
  output-stats-file   Text
    Output STATS file containing statistics for the clusters 
  output-subcluster-intersect-file   Text
    Output TSV file of Subclusters that mapped with existing clusters 
  output-subclusters-file   Text
    Output BED file of Subclusters for each cluster in the input BED file 
  subcluster-min-mapzero   Text
    Minimum %MapZero Alignments to call subclusters 
    Default value '2' if not specified

