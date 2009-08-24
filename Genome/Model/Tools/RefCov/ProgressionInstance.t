#!/gsc/bin/perl

use strict;
use warnings;

use Test::More tests => 4;

use above 'Genome';

use_ok('Genome::Model::Tools::RefCov::ProgressionInstance');

my $data_dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-RefCov/Progression';
my @bam_files = glob($data_dir .'/*.bam');
my $target_query_file = $data_dir .'/BACKBONE.tsv';
my $output_directory = File::Temp::tempdir(CLEANUP=>1);

my $progression_instance = Genome::Model::Tools::RefCov::ProgressionInstance->create(
    bam_files =>\@bam_files,
    target_query_file => $target_query_file,
    output_directory => $output_directory,
);

ok($progression_instance->execute(),'');

ok (-s $progression_instance->stats_file,'');

for my $size (qw/LARGE/) {
    ok(-s $progression_instance->bias_basename .'_'. $size,'');
}

exit;
