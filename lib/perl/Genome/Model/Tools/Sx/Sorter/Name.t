#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';

require File::Compare;
use Test::More;

use_ok('Genome::Model::Tools::Sx::Sorter::Name') or die;

# Files
my $dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Sx';
my $in_fastq = $dir.'/in.fastq';
ok(-s $in_fastq, 'in fastq');
my $example_fastq = $dir.'/sorter_name.example.fastq';
ok(-s $example_fastq, 'example fastq');

my $tmp_dir = File::Temp::tempdir(CLEANUP => 1);
my $out_fastq = $tmp_dir.'/out.fastq';

# Ok
my $sorter = Genome::Model::Tools::Sx::Sorter::Name->create(
    input  => [ $in_fastq ],
    output => [ $out_fastq ],
);
ok($sorter, 'create sorter');
isa_ok($sorter, 'Genome::Model::Tools::Sx::Sorter::Name');
ok($sorter->execute, 'execute sorter');
is(File::Compare::compare($example_fastq, $out_fastq), 0, "sorted as expected");

#print "$tmp_dir\n"; <STDIN>;
done_testing();
exit;

