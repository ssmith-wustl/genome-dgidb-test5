#!/gsc/bin/perl

use strict;
use warnings;

use above 'Genome';
use Genome;
exit;
#use Test::More skip_all => 'test data not in place yet....';
#use Test::More tests => 5;

#BEGIN {
#    use_ok('Genome::Model::Tools::PooledBac::CreateBACProjectDirectories');
#}
use Genome::Model::Tools::PooledBac::CreateProjectDirectories;
my $path = '/gsc/var/cache/Genome-Model-Tools-PooledBac';

my $project_dir = '/gscmnt/936/info/jschindl/pbtestout_final';

#my $pb_path = '/gscmnt/936/info/jschindl/pbintestdir';
#my $phd_ball = '/gscmnt/936/info/jschindl/pbintestdir/consed/phdball_dir/phd.ball';
#my $ace_file_name = 'pbtest.ace';
my $pb_path = '/gscmnt/232/finishing/projects/Fosmid_two_pooled_Combined/Fosmid_two_pooled70_combined_trim-1.0_090417.newb';
my $phd_ball = '/gscmnt/232/finishing/projects/Fosmid_two_pooled_Combined/Fosmid_two_pooled70_combined_trim-1.0_090417.newb/consed/phdball_dir/phd.ball.1';
my $ace_file_name = 'Pcap.454Contigs.ace.1';

Genome::Model::Tools::PooledBac::CreateProjectDirectories->execute(pooled_bac_dir=>$pb_path,ace_file_name => $ace_file_name,phd_file_name_or_dir => $phd_ball, project_dir => $project_dir);
1;
