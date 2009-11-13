#!/gsc/bin/perl

use strict;
use warnings;

use Test::More tests => 7;
use File::Compare;

use above 'Genome';

BEGIN {
    use_ok('Genome::Model::Tools::Fastq::Trimq2');
};

my $base_dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Fastq/Trimq2';

my $tmp_dir = File::Temp::tempdir('Fastq-Trimq2-XXXXX', DIR => '/gsc/var/cache/testsuite/running_testsuites', CLEANUP => 1);
my $sanger_fastq_file = "$base_dir/test.sanger.fastq";
my $sanger_expected_trim_fastq_file = "$base_dir/test.sanger.utf8.trimq2.fastq";
my $sanger_expected_trim_ori_file   = 

#Test sanger fastq, report yes, length_limit 32 bp
my $sanger_trimq2 = Genome::Model::Tools::Fastq::Trimq2->create(
    fastq_file => $sanger_fastq_file,
    out_file   => $tmp_dir .'/test.sanger.trimq2.fastq',
    output_dir => $tmp_dir,
    trimmed_original_fastq => 1,
);
isa_ok($sanger_trimq2,'Genome::Model::Tools::Fastq::Trimq2');

ok($sanger_trimq2->execute,'execute command '. $sanger_trimq2->command_name);

for my $file_type qw(trimq2.fastq trimq2.filtered.fastq trimmed_original.fastq trimq2.report) {
    my $output_file = $tmp_dir.'/test.sanger.'.$file_type;
    my $expect_file = $base_dir.'/test.sanger.utf8.'.$file_type;
    ok(compare($output_file, $expect_file) == 0, "Output $file_type is created as expected");
}

#TODO should also add Illumina fastq trim test

exit;
