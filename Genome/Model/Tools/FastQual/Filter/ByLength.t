#!/gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

require File::Compare;
use Test::More;

# use
use_ok('Genome::Model::Tools::FastQual::Filter::ByLength') or die;
use_ok('Genome::Model::Tools::Fastq::SetReader') or die;

# create fail
ok(!Genome::Model::Tools::FastQual::Filter::ByLength->create(), 'Create w/o filter length');
ok(!Genome::Model::Tools::FastQual::Filter::ByLength->create(filter_length => 'all'), 'Create w/ filter length => all');
ok(!Genome::Model::Tools::FastQual::Filter::ByLength->create(filter_length => 0), 'Create w/ filter length => 0');

# Files
my $dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-FastQual';
my $in_fastq = $dir.'/trimmer_bwa_style.example.fastq';
ok(-s $in_fastq, 'in fastq');
my $example_fastq = $dir.'/filter_by_length.example.fastq';
ok(-s $example_fastq, 'example fastq');

my $tmp_dir = File::Temp::tempdir(CLEANUP => 1);
my $out_fastq = $tmp_dir.'/out.fastq';

# Ok
my $filter = Genome::Model::Tools::FastQual::Filter::ByLength->create(
    input_files  => [ $in_fastq ],
    output_files => [ $out_fastq ],
    filter_length => 10,
);
ok($filter, 'create filter');
isa_ok($filter, 'Genome::Model::Tools::FastQual::Filter::ByLength');
ok($filter->execute, 'execute filter');
is(File::Compare::compare($example_fastq, $out_fastq), 0, "fastq filtered as expected");

done_testing();
exit;

#HeadURL$
#$Id$
