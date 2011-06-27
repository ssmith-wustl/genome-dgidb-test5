#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';

use Data::Dumper 'Dumper';
require File::Temp;
require File::Compare;
use Test::More;

#< Use >#
use_ok('Genome::Model::Tools::FastQual::IlluminaFastqReader') or die;
use_ok('Genome::Model::Tools::FastQual::IlluminaFastqWriter') or die;

#< Files >#
my $dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-FastQual/';
my $example_fastq = $dir.'/reader_writer.fastq';
ok(-s $example_fastq, 'example fastq exists') or die;

my $tmpdir = File::Temp::tempdir(CLEANUP => 1);
ok(-d $tmpdir, 'Created temp dir');
my $out_fastq = $tmpdir.'/out.fastq';

#< Read illumina, write illumina >#
note('Read illumina, converts to sanger, writer illumina, converts back');
my $reader = Genome::Model::Tools::FastQual::IlluminaFastqReader->create(
    files => [ $example_fastq ],
);
ok($reader, 'Create reader');
my $writer = Genome::Model::Tools::FastQual::IlluminaFastqWriter->create(
    files => [ $out_fastq ],
);
ok($writer, 'Create writer');
my $count = 0;
while ( my $fastqs = $reader->read ) {
    $count++;
    $writer->write($fastqs)
        or die;
}
is($count, 25, 'Read/write 25 fastq sets');
ok($writer->flush, 'flush');
is(File::Compare::compare($out_fastq, $example_fastq), 0, 'files match');

#print "$tmpdir\n"; <STDIN>;
done_testing();
exit;

