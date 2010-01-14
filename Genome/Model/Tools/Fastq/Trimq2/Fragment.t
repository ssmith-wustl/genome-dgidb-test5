#!/gsc/bin/perl

use strict;
use warnings;

use Test::More tests => 6;
use File::Compare;

use above 'Genome';

BEGIN {
    use_ok('Genome::Model::Tools::Fastq::Trimq2::Fragment');
};

my $base_dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Fastq/Trimq2/Fragment';

my $tmp_dir = File::Temp::tempdir(
    'Fastq-Trimq2-XXXXX', 
    DIR => '/gsc/var/cache/testsuite/running_testsuites', 
    CLEANUP => 1
);
my $fastq_file = "$base_dir/test_fragment.fastq";

#Test sanger fastq, report yes, length_limit 32 bp
my $trimq2 = Genome::Model::Tools::Fastq::Trimq2::Fragment->create(
    fastq_file  => $fastq_file,
    output_dir  => $tmp_dir,
    #trim_string => '#',  default is #
);
isa_ok($trimq2,'Genome::Model::Tools::Fastq::Trimq2');

ok($trimq2->execute,'execute command '. $trimq2->command_name);

for my $file qw(test_fragment.trimq2.fastq test_fragment.trimq2.filtered.fastq trimq2.report) {
    my $output_file = $tmp_dir."/$file";
    my $expect_file = $base_dir."/$file";
    ok(compare($output_file, $expect_file) == 0, "Output $file is created as expected");
}

#TODO should also add Illumina fastq trim test

exit;
