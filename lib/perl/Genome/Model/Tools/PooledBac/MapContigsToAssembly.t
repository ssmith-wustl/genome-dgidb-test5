#!/gsc/bin/perl

use strict;
use warnings;

use above 'Genome';
use Genome;
use Test::More skip_all => 'test data not in place yet....';
#exit;
#use Test::More tests => 5;

#BEGIN {
#    use_ok('Genome::Model::Tools::PooledBac::MapContigsToAssembly');
#}
use Genome::Model::Tools::PooledBac::MapContigsToAssembly;
my $path = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-PooledBac/';
my $pb_path = $path.'input_pb/';
my $ref_seq_file = $path.'ref_seq.txt';
my $project_dir = '/gscmnt/936/info/jschindl/pbtestout';
my $ace_file_name = 'pb.ace';

`rm -rf $project_dir/*`;
`mkdir -p $project_dir`;

Genome::Model::Tools::PooledBac::MapContigsToAssembly->execute(rpooled_bac_dir=>$pb_path,ace_file_name => $ace_file_name, project_dir => $project_dir);
1;
