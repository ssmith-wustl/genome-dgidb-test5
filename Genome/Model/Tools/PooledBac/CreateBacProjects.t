#!/gsc/bin/perl

use strict;
use warnings;

use above 'Genome';
use Genome;
use Test::More skip_all => 'test data not in place yet....';
exit;
#use Test::More tests => 5;

#BEGIN {
#    use_ok('Genome::Model::Tools::PooledBac::CreateBacProjectDirectories');
#}
use Genome::Model::Tools::PooledBac::CreateBacProjects;

my $project_dir = '/gscmnt/936/info/jschindl/pbtestout_final';

Genome::Model::Tools::PooledBac::CreateBacProjects->execute(project_dir => $project_dir);
1;
