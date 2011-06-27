#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';

require File::Temp;
require File::Compare;
use Test::More;

use_ok('Genome::Model::Tools::FastQual::BedWriter') or die;

my $tmpdir = File::Temp::tempdir(CLEANUP => 1);
ok(-d $tmpdir, 'temp dir');
my $dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-FastQual/';
my $fasta = $dir.'/bed_writer.fasta';
ok(-s $fasta, 'fasta exists') or die;
my $example_bed_file = $dir.'/bed_writer.v2.bed';
ok(-s $example_bed_file, 'example bed file exists');

my $reader = Genome::Model::Tools::FastQual::PhredReader->create(
    files => [ $fasta ],
);
ok($reader, 'fasta reader');
my $bed_file = $tmpdir.'/bed';
my $writer = Genome::Model::Tools::FastQual::BedWriter->create(
    files => [ $bed_file ],
);
ok($writer, 'bed writer');
my $count = 0;
while ( my $fastas = $reader->read ) {
    $count++;
    $writer->write($fastas)
        or die;
}
is($count, 2, 'Read/write 2 beds');
ok($writer->flush, 'flush');
is(File::Compare::compare($bed_file, $example_bed_file), 0, 'Bed file matches');

#print "$tmpdir\n"; <STDIN>;
done_testing();
exit;

