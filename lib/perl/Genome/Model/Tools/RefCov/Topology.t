#!/gsc/bin/perl

use strict;
use warnings;

use Test::More tests => 4;
use File::Compare;
use above 'Genome';

BEGIN {
        use_ok('Genome::Model::Tools::RefCov::Topology');  
};

my $data_dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-RefCov/Topology';
my $frozen_file = $data_dir .'/__SAT1.rc';
my $expected_file = $data_dir .'/topology_2.dat';

my $tmp_dir = File::Temp::tempdir('RefCov-Topology-'. $ENV{USER} .'-XXXX',DIR=>'/gsc/var/cache/testsuite/running_testsuites',CLEANUP=>1);
my $output_file = $tmp_dir .'/topology.dat';

my $topo_cmd = Genome::Model::Tools::RefCov::Topology->create(
                                                              frozen_file => $frozen_file,
                                                              output_file => $output_file,
                                                          );

isa_ok($topo_cmd,'Genome::Model::Tools::RefCov::Topology');

ok($topo_cmd->execute,'execute topology command '. $topo_cmd->command_name);
ok(!compare($expected_file,$output_file),'output matches expected file');

exit;
