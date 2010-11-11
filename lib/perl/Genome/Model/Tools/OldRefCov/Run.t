#!/gsc/bin/perl

use strict;
use warnings;

use Test::More tests => 4;
use File::Compare;

use above 'Genome';

BEGIN {
        use_ok('Genome::Model::Tools::OldRefCov::Run');
}

my $tmp_dir = File::Temp::tempdir('RefCov-'.$ENV{USER}.'-XXXX',DIR => '/gsc/var/cache/testsuite/running_testsuites',CLEANUP => 1);

my $data_dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-RefCov';

my $layers_file_path = $data_dir .'/test.layers';
my $genes_file_path = $data_dir .'/test.genes';
my $expected_stats_file = $data_dir .'/STATS.tsv';

my $ref_cov = Genome::Model::Tools::OldRefCov::Run->create(
                                                        base_output_directory => $tmp_dir,
                                                        layers_file_path => $layers_file_path,
                                                        genes_file_path => $genes_file_path,
                                                    );
isa_ok($ref_cov,'Genome::Model::Tools::OldRefCov::Run');
ok($ref_cov->execute,'execute RefCov command '. $ref_cov->command_name);

ok(!compare($expected_stats_file,$ref_cov->stats_file_path),'got expected stats output');


exit;
