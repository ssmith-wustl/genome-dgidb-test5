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
use Genome::Model::Tools::PooledBac::CreateBACProjects;

my $project_dir = '/gscmnt/936/info/jschindl/pbtestout_final';

Genome::Model::Tools::PooledBac::CreateBACProjects->execute(project_dir => $project_dir);
1;
