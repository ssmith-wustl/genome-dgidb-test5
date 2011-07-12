#!/usr/bin/perl;

use above 'Genome';
use strict;
use warnings;

use Test::More;
my $output_dir = '/gscuser/tdutton/test/indel_filter';
mkdir $output_dir unless -d $output_dir;
my $output_file = $output_dir.'/out.hq';
my $lq_file = $output_dir.'/out.lq';
my $indel_input_file = '/gscmnt/gc2000/info/build_merged_alignments/detect-variants--blade14-2-14.gsc.wustl.edu-tdutton-18023-112544070/indels.hq';
my $indel_filter_command = Genome::Model::Tools::Sam::IndelFilter->create(
    indel_file => $indel_input_file,
    out_file => $output_file,
    lq_file => $lq_file,
    max_read_depth=>100,
    min_win_size=>10,
    scaling_factor=>100,
);

ok ($indel_filter_command, 'created command');

isa_ok($indel_filter_command, 'Genome::Model::Tools::Sam::IndelFilter', 'command is a indel filter object');

ok ($indel_filter_command->execute, 'Execute command executed');

ok (-s $output_file, 'output file has size');

