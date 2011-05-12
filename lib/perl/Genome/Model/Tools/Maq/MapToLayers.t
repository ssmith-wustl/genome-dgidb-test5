#!/gsc/bin/perl

use strict;
use warnings;

use Test::More;
use File::Compare;

use above 'Genome';

BEGIN {
    if (`uname -a` =~ /x86_64/){
        plan tests => 7;
    } else{
        plan skip_all => 'Must run on a 64 bit machine';
    }
    use_ok('Genome::Model::Tools::Maq::MapToLayers');
}

my $map_file = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Maq-Map/2.map';
my $expected_layers_file = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Maq-Map/3.map.layers';
my $tmp_dir = File::Temp::tempdir('Map-To-Layers-'. Genome::Sys->username .'-XXXX', DIR => '/gsc/var/cache/testsuite/running_testsuites', CLEANUP => 1);
my $cmd = Genome::Model::Tools::Maq::MapToLayers->create(
                                                         map_file => $map_file,
                                                         layers_file => $tmp_dir .'/2.layers',
                                                     );
isa_ok($cmd,'Genome::Model::Tools::Maq::MapToLayers');
ok($cmd->execute,'execute command '. $cmd->command_name);
ok(!compare($expected_layers_file,$cmd->layers_file),'layers file matches expected');

my $rand_cmd = Genome::Model::Tools::Maq::MapToLayers->create(
                                                              map_file => $map_file,
                                                              layers_file => $tmp_dir .'/2.randomized.layers',
                                                              randomize => 1,
                                                     );
isa_ok($rand_cmd,'Genome::Model::Tools::Maq::MapToLayers');
ok($rand_cmd->execute,'execute command '. $rand_cmd->command_name);
ok(compare($expected_layers_file,$rand_cmd->layers_file),'randomized layers file does not match expected');

exit;
