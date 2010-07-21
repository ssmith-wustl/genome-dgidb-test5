#!/gsc/bin/perl

use strict;
use warnings;

use Test::More tests => 4;
use File::Compare;

use above 'Genome';

BEGIN{
    use_ok('Genome::Model::Tools::RefCov::MergeStatsFiles');
};

my $data_dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-RefCov/MergeStatsFiles';

my @stats_files = grep { $_ !~ /STATS\.tsv/} glob($data_dir.'/STATS*.tsv');
my $expected_stats_file = $data_dir .'/STATS.tsv';
my $tmp_dir = File::Temp::tempdir('RefCov-MergeStatsFiles-'.$ENV{USER}.'-XXXX',DIR => '/gsc/var/cache/testsuite/running_testsuites',CLEANUP => 1);
my $output_stats_file = $tmp_dir .'/STATS.tsv';

my $merge = Genome::Model::Tools::RefCov::MergeStatsFiles->create(
                                                                  input_stats_files => \@stats_files,
                                                                  output_stats_file => $output_stats_file,
                                                              );
isa_ok($merge,'Genome::Model::Tools::RefCov::MergeStatsFiles');
ok($merge->execute,'execute command '. $merge->command_name);
ok(!compare($expected_stats_file,$output_stats_file),'stats file matches expected');

exit;
