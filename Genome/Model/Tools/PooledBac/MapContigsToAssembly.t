#!/gsc/bin/perl

use strict;
use warnings;

use above 'Genome';
use Genome;
exit;
#use Test::More skip_all => 'test data not in place yet....';
#use Test::More tests => 5;

#BEGIN {
#    use_ok('Genome::Model::Tools::PooledBac::MapContigsToAssembly');
#}
use Genome::Model::Tools::PooledBac::MapContigsToAssembly;
my $path = '/gsc/var/cache/Genome-Model-Tools-PooledBac';

#my $pb_path = '/gscmnt/936/info/jschindl/pbintestdir';
#my $ace_file_name = 'pbtest.ace';
my $pb_path = '/gscmnt/232/finishing/projects/Fosmid_two_pooled_Combined/Fosmid_two_pooled70_combined_trim-1.0_090417.newb';
my $ace_file_name = 'Pcap.454Contigs.ace.1';

my $ref_seq_path = '/gscmnt/839/info/medseq/reference_sequences/NCBI-human-build36/';
my $ref_seq_file = '/gscuser/jschindl/ref_seq_file2.txt';
my $project_dir = '/gscmnt/936/info/jschindl/pbtestout_for_tina';
`rm -rf $project_dir/*`;
`mkdir -p $project_dir`;

Genome::Model::Tools::PooledBac::MapContigsToAssembly->execute(ref_sequence=>$ref_seq_file,pooled_bac_dir=>$pb_path,pooled_bac_ace_file => $ace_file_name, project_dir => $project_dir);
1;
