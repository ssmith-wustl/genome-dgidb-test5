#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";
use Test::More tests => 4;
use File::Compare;
use File::Temp qw(tempfile);

use_ok( 'Genome::Model::Tools::Breakdancer::MergeFiles');

my $tmp_dir = File::Temp::tempdir(
    'Genome-Model-Tools-Breakdancer-MergeFiles-XXXXX', 
    DIR     => '/gsc/var/cache/testsuite/running_testsuites', 
    CLEANUP => 1,
);

my $dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Breakdancer-MergeFiles';
my @in_files   = map{$dir.'/'.$_}qw(file1.in file2.in);
my $expect_out = $dir . '/file3.out';
my $merge_file = $tmp_dir .'/merge.out';
my $in_files = join ',', @in_files;

my $merge = Genome::Model::Tools::Breakdancer::MergeFiles->create(
    input_files => $in_files,
    output_file => $merge_file,
);

ok($merge, 'merge created ok');
ok($merge->execute(), 'merge executed ok');

is(compare($merge_file, $expect_out), 0, 'merge output is generated as expected');

