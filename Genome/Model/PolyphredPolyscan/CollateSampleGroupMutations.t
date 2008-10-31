#!/usr/bin/env perl

use strict;
use warnings;
use Test::More tests => 7;
use above "Genome";

my $data_path = '/gsc/var/cache/testsuite/data/Genome-Model-PolyphredPolyscan-CollateSampleGroupMutations';

use_ok('Genome::Model::PolyphredPolyscan::CollateSampleGroupMutations');

my $command = Genome::Model::PolyphredPolyscan::CollateSampleGroupMutations->create(
    parser_type => 'Polyscan',
    input_file => $data_path . '/Polyscan.input/TCGA_Production_Set_1-0000199_00n-Ensembl-44_36f.polyscan.high',
    output_path => '/tmp'
);

ok($command,'got command object');
ok($command->execute,'executed command object');
is($command->result,1,'result is 1');

ok(-e $command->output_file,'output file exists');
ok(-s $command->output_file,'output file has size');

system('sort -gk1 -gk2 -k4 ' . $command->output_file . '>' . $command->output_file . '.sorted');

my $linecount = 0;
my $lines = '';
open(FH, 'diff ' . $data_path . '/Polyscan.sorted_output ' . $command->output_file . '.sorted |');
while (my $line = <FH>) {
    $linecount++;
    $lines .= $line;
}
close FH;

#unlink $command->output_file . '.sorted';
#unlink $command->output_file;

is($linecount,0,'zero differences between saved result');
diag($lines) if $linecount > 0;

