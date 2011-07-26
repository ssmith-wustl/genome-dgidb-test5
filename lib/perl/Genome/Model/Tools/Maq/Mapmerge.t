#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use File::Compare;

use above 'Genome';

BEGIN {
    if (`uname -a` =~ /x86_64/){
        plan tests => 26;
    }
    else{
        plan skip_all => 'Must run on a 64 bit machine';
    }
    use_ok('Genome::Model::Tools::Maq');
    use_ok('Genome::Model::Tools::Maq::Mapmerge');
};

my $data_dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Maq-Mapmerge';
my $expected_output_map = $data_dir .'/all.map';
ok(-s $expected_output_map,'expected output file exists with size');

my @input_map_files = grep { $_ ne $expected_output_map } glob($data_dir .'/*.map');
is(scalar(@input_map_files),3,'found 3 input map file paths');

my @bogus_map_files;
for my $file (@input_map_files) {
    my $bogus_file = $file;
    $bogus_file =~ s/map/bogus\.map/;
    push @bogus_map_files, $bogus_file;
}
is(scalar(@bogus_map_files),3,'found 3 bogus input map file paths');

my $tmp_dir  = File::Temp::tempdir(
                                   "Mapmerge_XXXXXX",
                                   DIR     => '/gsc/var/cache/testsuite/running_testsuites',
                                   CLEANUP => 1,
                               );
my $tmp_output_map = $tmp_dir .'/correct.map';
Genome::Model::Tools::Maq::Mapmerge->dump_error_messages(0);

my $mapmerge_cmd;
eval {
    $mapmerge_cmd = Genome::Model::Tools::Maq::Mapmerge->create();
};
ok(!$mapmerge_cmd,'failed to create without input map files');
like($@,qr/^Input map files are required/,'found expected error message about required input files');

eval {
    $mapmerge_cmd = Genome::Model::Tools::Maq::Mapmerge->create(input_map_files => $expected_output_map);
};
ok(!$mapmerge_cmd,'failed to create without array ref of input map files');
like($@,qr/^Input map files must be an array reference or list of files/,'found expected error message about array ref of input files');

eval {
    $mapmerge_cmd = Genome::Model::Tools::Maq::Mapmerge->create(input_map_files => $expected_output_map);
};
ok(!$mapmerge_cmd,'failed to create without array ref of input map files');
like($@,qr/^Input map files must be an array reference or list of files/,'found expected error message about array ref of input files');

eval {
    $mapmerge_cmd = Genome::Model::Tools::Maq::Mapmerge->create(input_map_files => []);
};
ok(!$mapmerge_cmd,'failed to create without more than one map file');
like($@,qr/^Must have more than one input map files/,'found expected error message about less than one input file');

eval {
    $mapmerge_cmd = Genome::Model::Tools::Maq::Mapmerge->create(input_map_files => \@bogus_map_files);
};
ok(!$mapmerge_cmd,'failed to create without existing input map files');
like($@,qr/^Map file .* not found or has zero size/,'found expected error message about non-existant input files');

eval {
    $mapmerge_cmd = Genome::Model::Tools::Maq::Mapmerge->create(input_map_files => \@input_map_files);
};
ok(!$mapmerge_cmd,'failed to create without output file path');
like($@,qr/^Output map file is required/,'found expected error message about required output file');

eval {
    $mapmerge_cmd = Genome::Model::Tools::Maq::Mapmerge->create(
                                                                input_map_files => \@input_map_files,
                                                                output_map_file => $expected_output_map,
                                                            );
};
ok(!$mapmerge_cmd,'failed to create with existing output map file');
like($@,qr/^Output map file .* already exists/,'found expected error message about existing output file');

$mapmerge_cmd = Genome::Model::Tools::Maq::Mapmerge->create(
                                                            use_version => '0.7.1',
                                                            input_map_files => \@input_map_files,
                                                            output_map_file => $tmp_output_map,
                                                        );
isa_ok($mapmerge_cmd,'Genome::Model::Tools::Maq::Mapmerge');

ok($mapmerge_cmd->execute,'execute command '. $mapmerge_cmd->command_name);

ok(!compare($tmp_output_map,$expected_output_map),'output map file is same as expected');


shift(@input_map_files);
$tmp_output_map = $tmp_dir .'/incorrect.map';
is(scalar(@input_map_files),2,'now we only have two of the input files');
$mapmerge_cmd = Genome::Model::Tools::Maq::Mapmerge->create(
                                                            use_version => '0.7.1',
                                                            input_map_files => \@input_map_files,
                                                            output_map_file => $tmp_output_map,
                                                        );
isa_ok($mapmerge_cmd,'Genome::Model::Tools::Maq::Mapmerge');
ok($mapmerge_cmd->execute,'execute command '. $mapmerge_cmd->command_name);
ok(compare($tmp_output_map,$expected_output_map),'output map file is different as expected');

exit;
