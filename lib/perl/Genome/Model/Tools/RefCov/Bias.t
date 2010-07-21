#!/gsc/bin/perl

use strict;
use warnings;

use Test::More tests => 7;
use File::Compare;
use above 'Genome';

BEGIN {
        use_ok('Genome::Model::Tools::RefCov::Bias');
};

my $dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-RefCov/Bias';

my $data_file = 'bias.dat';
my @sizes = qw/SMALL MEDIUM LARGE/;
my $image_file = 'bias.png';

my $tmp_dir = File::Temp::tempdir('RefCov-Bias-'. $ENV{USER} .'-XXXX',DIR=>'/gsc/var/cache/testsuite/running_testsuites',CLEANUP=>1);


my $output_image_file = $tmp_dir .'/'. $image_file;
my $expected_image_file = $dir .'/'. $image_file;
my $output_data_file = $tmp_dir .'/'. $data_file;
my $expected_data_file = $dir .'/'. $data_file;

my $cmd = Genome::Model::Tools::RefCov::Bias->create(
                                                     frozen_directory => $dir .'/FROZEN',
                                                     image_file => $output_image_file,
                                                     output_file => $output_data_file,
                                                     sample_name => 'test',
                                                 );
isa_ok($cmd,'Genome::Model::Tools::RefCov::Bias');
ok($cmd->execute,'execute bias command');

for my $size (@sizes) {
    $output_image_file = $tmp_dir .'/bias_'. $size .'.png';
    # can not compare files since there could be meta differences
    ok(-s $output_image_file, 'output image file '. $output_image_file .' has size');
}
ok(!compare($expected_data_file,$output_data_file),'output matches expected data file');

exit;
