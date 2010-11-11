#!/gsc/bin/perl

use strict;
use warnings;

use Test::More skip_all => 'This test will complete outside of the testing harness.  It uses a different version of perl and will not succeed in a test harness.';

use above 'Genome';

if (`uname -a` =~ /x86_64/){
    plan tests => 4;
} else{
    plan skip_all => 'Must run on a 64 bit machine';
}

use_ok('Genome::Model::Tools::OldRefCov::ProgressionInstance');

my $data_dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-RefCov/Progression';
my @bam_files = glob($data_dir .'/*.bam');
my $target_query_file = $data_dir .'/BACKBONE.tsv';
my $output_directory = File::Temp::tempdir(CLEANUP=>1);

my $progression_instance = Genome::Model::Tools::OldRefCov::ProgressionInstance->create(
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
