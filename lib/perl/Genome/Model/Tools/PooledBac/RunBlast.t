#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';

use Data::Dumper 'Dumper';
use Test::More; 

use_ok('Genome::Model::Tools::PooledBac::RunBlast') or die;

my $run_blast = Genome::Model::Tools::PooledBac::RunBlast->create(
);
ok($run_blast, 'create');
#print Dumper($run_blast);
#ok($run_blast->execute, 'execute');

done_testing();
exit;

