#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use File::Compare;

use above 'Genome';

BEGIN {
    if (`uname -a` =~ /x86_64/){
        plan tests => 11;
    }
    else{
        plan skip_all => 'Must run on a 64 bit machine';
    }
    use_ok('Genome::Model::Tools::Maq');
    use_ok('Genome::Model::Tools::Maq::Mapview');
};
my $data_dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Maq-Mapview';
my $expected_output_map = $data_dir .'/all.map.out';
my $map_file = $data_dir .'/all.map';
my $bogus_map_file = $data_dir .'/all.bogus.map';

my $tmp_dir  = File::Temp::tempdir(
                                   "Mapview_XXXXXX",
                                   DIR     => '/gsc/var/cache/testsuite/running_testsuites',
                                   CLEANUP => 1,
                               );
my $output_mapview = $tmp_dir .'/correct.map.out';

Genome::Model::Tools::Maq::Mapview->dump_error_messages(1);

my $mapview_cmd;
eval {
    $mapview_cmd = Genome::Model::Tools::Maq::Mapview->create();
};
ok(!$mapview_cmd,'failed to create without map file');
like($@,qr/^Map file is required/,'found expected error message about required map file');

eval {
    $mapview_cmd = Genome::Model::Tools::Maq::Mapview->create(map_file => $bogus_map_file);
};
ok(!$mapview_cmd,'failed to create without existing map file');
like($@,qr/^Map file .* not found or has zero size/,'found expected error message about non-existant map file');

eval {
    $mapview_cmd = Genome::Model::Tools::Maq::Mapview->create(
                                                              map_file => $map_file,
                                                              output_file => $expected_output_map,
                                                          );
};
ok(!$mapview_cmd,'failed to create with existing output file');
like($@,qr/^Output file .* already exists/,'found expected error message about existing output file');

$mapview_cmd = Genome::Model::Tools::Maq::Mapview->create(
                                                          use_version => '0.7.1',
                                                          map_file => $map_file,
                                                          output_file => $output_mapview,
                                                      );
isa_ok($mapview_cmd,'Genome::Model::Tools::Maq::Mapview');
ok($mapview_cmd->execute,'execute command '. $mapview_cmd->command_name);
ok(!compare($output_mapview,$expected_output_map),'files are the same');

exit;
