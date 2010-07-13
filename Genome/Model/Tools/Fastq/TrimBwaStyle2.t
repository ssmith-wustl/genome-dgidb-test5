#!/gsc/bin/perl

use strict;
use warnings;

use Test::More tests => 7;
use File::Compare;

use above 'Genome';

BEGIN {
    use_ok('Genome::Model::Tools::Fastq::TrimBwaStyle2');
    use_ok('Genome::Model::Tools::Fastq::SetReader') or die;
};

my $base_dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Fastq-TrimBwaStyle';

my $tmp_dir = File::Temp::tempdir(
    'Fastq-TrimBwaStyle-XXXXX', 
    DIR => '/gsc/var/cache/testsuite/running_testsuites', 
    CLEANUP => 1
);
my $fastq_file = "$base_dir/test.fastq";

my $trim = Genome::Model::Tools::Fastq::TrimBwaStyle2->create(
    input_files  => [$fastq_file],
    output_files => [$tmp_dir.'/test.trimmed.fastq'],
    trim_report  => 1,
    type         => 'sanger',
);
isa_ok($trim,'Genome::Model::Tools::Fastq::TrimBwaStyle2');

ok($trim->execute,'execute command '. $trim->command_name);

for my $file qw(test.trimmed.fastq trim.report) {
    my $output_file = $tmp_dir."/$file";
    my $expect_file = $base_dir."/$file";
    ok(compare($output_file, $expect_file) == 0, "Output: $file is created as expected");
}

my $fastq1 = $base_dir.'/1.fastq';
my $fastq2 = $base_dir.'/2.fastq';

my $reader = Genome::Model::Tools::Fastq::SetReader->create(
    fastq_files => [ $fastq1, $fastq2 ],
);

my $trim2 = Genome::Model::Tools::Fastq::TrimBwaStyle2->create(
    trim_qual_level => 10,
    type            => 'illumina',
);

my $total_base_after_trim = 0;

while (my $pairfq = $reader->next ) {
    $trim2->trim($pairfq);
    for my $fq (@$pairfq) {
        $total_base_after_trim += length $fq->{seq};
    }
}

is($total_base_after_trim, 1174, 'There are total 1174 bases after trim as expected');

exit;
