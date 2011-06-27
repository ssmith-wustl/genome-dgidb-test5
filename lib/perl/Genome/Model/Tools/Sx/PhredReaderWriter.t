#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';

use Data::Dumper 'Dumper';
require File::Temp;
require File::Compare;
use Test::More;

#< Use >#
use_ok('Genome::Model::Tools::Sx::PhredReader') or die;
use_ok('Genome::Model::Tools::Sx::PhredWriter') or die;

#< Files >#
my $dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Sx';
my $input_fasta = $dir.'/reader_writer.fasta';
ok(-s $input_fasta, 'Input fasta exists') or die;
my $input_qual = $input_fasta.'.qual';
ok(-s $input_qual, 'Input qual exists') or die;
my $tmpdir = File::Temp::tempdir(CLEANUP => 1);
ok(-d $tmpdir, 'Created temp dir');
my $output_fasta = $tmpdir.'/fasta';
my $output_qual = $tmpdir.'/qual';

#< Create Reader/Writer >#
my $reader = Genome::Model::Tools::Sx::PhredReader->create(
    files => [ $input_fasta, $input_qual ],
);
ok($reader, 'Create reader');

my $writer = Genome::Model::Tools::Sx::PhredWriter->create(
    files => [ $output_fasta, $output_qual ],
);
ok($writer, 'Create writer');

#< Read/Write >#
my $count = 0;
while ( my $seq = $reader->read ) {
    $count++;
    $writer->write($seq);
}
is($count, 10, 'Read/write 10 sequences');
ok($writer->flush, 'flush');
ok(-s $output_fasta, 'output fasta exists');
is(File::Compare::compare($input_fasta, $output_fasta), 0, 'In/out-put fastas match');
ok(-s $output_qual, 'output qual exists');
is(File::Compare::compare($input_qual, $output_qual), 0, 'In/out-put qauls match');

#< Reader Fails >#
my $id_does_not_match = $dir.'/reader_writer.id_does_not_match.fasta.qual';
$reader = Genome::Model::Tools::Sx::PhredReader->create(
    files => [ $input_fasta, $id_does_not_match ],
);
ok($reader, 'Create reader');
my $rv = eval{ $reader->read; };
diag($@);
ok((!$rv && $@ =~ /^Fasta and quality ids do not match:/), 'Failed when base and quals do not match');
my $quals_do_not_match = $dir.'/reader_writer.quals_do_not_match.fasta.qual';
$reader = Genome::Model::Tools::Sx::PhredReader->create(
    files => [ $input_fasta, $quals_do_not_match ],
);
ok($reader, 'Create reader');
$rv = eval{ $reader->read; };
diag($@);
ok((!$rv && $@ =~ /^Number of qualities does not match/), 'Failed when id in fasta does not match qual');

#print $tmpdir; <STDIN>;
done_testing();
exit;

