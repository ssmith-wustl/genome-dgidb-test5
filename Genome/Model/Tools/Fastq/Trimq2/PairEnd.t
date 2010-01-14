#!/gsc/bin/perl

use strict;
use warnings;

use Test::More tests => 9;
use File::Compare;

use above 'Genome';

BEGIN {
    use_ok('Genome::Model::Tools::Fastq::Trimq2::PairEnd');
};

my $base_dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Fastq/Trimq2/PairEnd';

my $tmp_dir = File::Temp::tempdir(
    'Fastq-Trimq2-XXXXX', 
    DIR => '/gsc/var/cache/testsuite/running_testsuites', 
    CLEANUP => 1
);

my $pe1_fq = $base_dir.'/test_pair_end_1.fastq';
my $pe2_fq = $base_dir.'/test_pair_end_2.fastq';

#Test sanger fastq, report yes, length_limit 32 bp
my $sanger_trimq2 = Genome::Model::Tools::Fastq::Trimq2::PairEnd->create(
    pair1_fastq_file => $pe1_fq,
    pair2_fastq_file => $pe2_fq,
    output_dir       => $tmp_dir,
    trim_string      => 'E',
);
isa_ok($sanger_trimq2,'Genome::Model::Tools::Fastq::Trimq2');

ok($sanger_trimq2->execute,'execute command '. $sanger_trimq2->command_name);

for my $file qw(trimq2.pair_as_fragment.fastq test_pair_end_1.trimq2.fastq test_pair_end_2.trimq2.fastq test_pair_end_1.trimq2.filtered.fastq test_pair_end_2.trimq2.filtered.fastq trimq2.report) {
    my $output_file = $tmp_dir."/$file";
    my $expect_file = $base_dir."/$file";
    ok(compare($output_file, $expect_file) == 0, "Output $file is created as expected");
}

#TODO should also add Illumina fastq trim test

exit;
