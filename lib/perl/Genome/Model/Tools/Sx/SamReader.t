#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';

require File::Temp;
require File::Compare;
use Test::More;

use_ok('Genome::Model::Tools::Sx::SamReader') or die;

my $tmpdir = File::Temp::tempdir(CLEANUP => 1);
ok(-d $tmpdir, 'Created temp dir');
my $fasta = $tmpdir.'/out.fasta';
my $qual = $tmpdir.'/out.qual';

my $dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Sx/';
my $sam = $dir.'/reader_writer.sam';
ok(-s $sam, 'sam exists') or die;
my $example_fasta = $dir.'/reader_writer.sam.fasta';
ok(-s $example_fasta, 'example fasta exists') or die;
my $example_qual = $example_fasta.'.qual';
ok(-s $example_qual, 'example qual exists') or die;

my $cmd = "gmt sx -input $sam -output file=$fasta:qual_file=$qual";
my $rv = eval{ Genome::Sys->shellcmd(cmd => $cmd); };

is(File::Compare::compare($example_fasta, $fasta), 0, 'fasta files match');
is(File::Compare::compare($example_qual, $qual), 0, 'qual files match');

#print "$tmpdir\n"; <STDIN>;
done_testing();
exit;

