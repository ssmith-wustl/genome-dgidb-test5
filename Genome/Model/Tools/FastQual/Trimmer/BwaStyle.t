#!/gsc/bin/perl

use strict;
use warnings;

use Test::More;
use File::Compare;

use above 'Genome';

use_ok('Genome::Model::Tools::FastQual::Trimmer::BwaStyle') or die;

my $base_dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Fastq-TrimBwaStyle';

my $tmp_dir = File::Temp::tempdir(
    'Fastq-Trimming::BwaStyle-XXXXX', 
    DIR => '/gsc/var/cache/testsuite/running_testsuites', 
    CLEANUP => 1
);
my $fastq_file = "$base_dir/test.fastq";

my $trim = Genome::Model::Tools::FastQual::Trimmer::BwaStyle->create(
    input_files  => [$fastq_file],
    output_files => [$tmp_dir.'/test.trimmed.fastq'],
);
isa_ok($trim,'Genome::Model::Tools::FastQual::Trimmer::BwaStyle');

ok($trim->execute,'execute command '. $trim->command_name);

for my $file qw(test.trimmed.fastq) {
    my $output_file = $tmp_dir."/$file";
    my $expect_file = $base_dir."/$file";
    ok(compare($output_file, $expect_file) == 0, "Output: $file is created as expected");
}

done_testing();
exit;

#$HeadURL$
#$Id$
