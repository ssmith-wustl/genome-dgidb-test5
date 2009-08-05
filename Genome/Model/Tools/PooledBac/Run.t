#!/gsc/bin/perl

use strict;
use warnings;

use above 'Genome';
use Genome;

use Genome::Model::Tools::PooledBac::Run;
use Test::More skip_all => "Test data not in place yet.";
exit;
my $path = '/gsc/var/cache/Genome-Model-Tools-PooledBac';

my $pb_path = '/gscmnt/232/finishing/projects/Fosmid_two_pooled_Combined/Fosmid_two_pooled70_combined_trim-1.0_090417.newb';

my $ref_seq_file = '/gscuser/jschindl/ref_seq_file2.txt';
my $project_dir = '/gscmnt/936/info/jschindl/pbtestout_final';
`rm -rf $project_dir/*`;
`mkdir -p $project_dir`;

Genome::Model::PooledBac::Run->execute(ref_seq_file=>$ref_seq_file,pooled_bac_dir=>$pb_path, project_dir => $project_dir);
