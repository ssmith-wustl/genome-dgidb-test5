#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

require File::Compare;
use Test::More;

use_ok('Genome::Model::Tools::FastQual::Collate') or die;

my $dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-FastQual/';
my $collated_fastq = $dir.'/set_reader_writer.collated.fastq';
ok(-s $collated_fastq, 'Collated fastq exists') or die;
my $forward_fastq = $dir.'/set_reader_writer.forward.fastq';
ok(-s $forward_fastq, 'Forward fastq exists') or die;
my $reverse_fastq = $dir.'/set_reader_writer.reverse.fastq';
ok(-s $reverse_fastq, 'Reverse fastq exists') or die;

my $tmp_dir = File::Temp::tempdir(CLEANUP => 1);
my $out_fastq = $tmp_dir.'/out.fastq';

# fails
my $failed_collate = Genome::Model::Tools::FastQual::Collate->execute(
    input => [ $forward_fastq ],
    output => [ $out_fastq ],
);
ok(!$failed_collate, 'execute failed w/ only one input file');
$failed_collate = Genome::Model::Tools::FastQual::Collate->execute(
    input => [ $forward_fastq, $reverse_fastq],
    output => [ $out_fastq, $out_fastq ],
);
ok(!$failed_collate, 'execute failed w/ 2 output file');

# ok
my $collate = Genome::Model::Tools::FastQual::Collate->create(
    input => [ $forward_fastq, $reverse_fastq ],
    output => [ $out_fastq ],
);
ok($collate, 'create');
ok($collate->execute, 'execute');
is(File::Compare::compare($collated_fastq, $out_fastq), 0, 'collated as expected');

#print "$tmp_dir\n"; <STDIN>;
done_testing();
exit;

