#!/usr/bin/env perl5.12.1

use strict;
use warnings;

use Test::More;

use above 'Genome';

if ($] < 5.012) {
    plan skip_all => "this test is only runnable on perl 5.12+"
}
plan tests => 4;

use_ok('Genome::Model::Tools::BioSamtools::ProgressionInstance');

my $data_dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-RefCov/Progression';
my @bam_files = glob($data_dir .'/*.bam');
my $target_query_file = $data_dir .'/BACKBONE.tsv';
my $output_directory = Genome::Sys->create_temp_directory();

my $progression_instance = Genome::Model::Tools::BioSamtools::ProgressionInstance->create(
    bam_files =>\@bam_files,
    target_query_file => $target_query_file,
    output_directory => $output_directory,
);

ok($progression_instance->execute(),'execute command '. $progression_instance->command_name);

ok (-s $progression_instance->stats_file,'stats file has size');

for my $size (qw/LARGE/) {
    ok(-s $progression_instance->bias_basename .'_'. $size,'size fraction '. $size .' bias has size');
}

exit;
