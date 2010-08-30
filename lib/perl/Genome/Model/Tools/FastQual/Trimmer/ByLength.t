#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";

require File::Compare;
use Test::More;

# Use
use_ok('Genome::Model::Tools::FastQual::Trimmer::ByLength') or die;

# Create failures
ok(!Genome::Model::Tools::FastQual::Trimmer::ByLength->create(), 'Create w/o trim length');
ok(!Genome::Model::Tools::FastQual::Trimmer::ByLength->create(trim_length => 'all'), 'Create w/ trim length => all');
ok(!Genome::Model::Tools::FastQual::Trimmer::ByLength->create(trim_length => 0), 'Create w/ trim length => 0');

# Files
my $dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-FastQual';
my $in_fastq = $dir.'/trimmer.in.fastq';
ok(-s $in_fastq, 'in fastq');
my $example_fastq = $dir.'/trimmer_by_length.example.fastq';
ok(-s $example_fastq, 'example fastq');

my $tmp_dir = File::Temp::tempdir(CLEANUP => 1);
my $out_fastq = $tmp_dir.'/out.fastq';

# Ok
my $trimmer = Genome::Model::Tools::FastQual::Trimmer::ByLength->create(
    input  => [ $in_fastq ],
    output => [ $out_fastq ],
    trim_length => 10,
);
ok($trimmer, 'create trimmer');
isa_ok($trimmer, 'Genome::Model::Tools::FastQual::Trimmer::ByLength');
ok($trimmer->execute, 'execute trimmer');
is(File::Compare::compare($example_fastq, $out_fastq), 0, "fastq trimmed as expected");

done_testing();
exit;

#HeadURL$
#$Id$
