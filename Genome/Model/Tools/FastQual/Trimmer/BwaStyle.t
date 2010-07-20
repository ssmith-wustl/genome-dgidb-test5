#!/gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

require File::Compare;
use Test::More;

# Use
use_ok('Genome::Model::Tools::FastQual::Trimmer::BwaStyle') or die;

# Create fails
ok(
    !Genome::Model::Tools::FastQual::Trimmer::BwaStyle->create(trim_qual_level => 'pp'),
    'create w/ trim_qual_level => pp'
);
ok(
    !Genome::Model::Tools::FastQual::Trimmer::BwaStyle->create(trim_qual_level => -1),
    'create w/ trim_qual_level => -1'
);

# Files
my $dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-FastQual';
my $in_fastq = $dir.'/trimmer.in.fastq';
ok(-s $in_fastq, 'in fastq');
my $example_fastq = $dir.'/trimmer_bwa_style.example.fastq';
ok(-s $example_fastq, 'example fastq');

my $tmp_dir = File::Temp::tempdir(
    'Fastq-Trimming::BwaStyle-XXXXX', 
    DIR => '/gsc/var/cache/testsuite/running_testsuites', 
    CLEANUP => 1
);
my $out_fastq = $tmp_dir.'/out.fastq';

# Ok
my $trimmer = Genome::Model::Tools::FastQual::Trimmer::BwaStyle->create(
    input_files  => [ $in_fastq ],
    output_files => [ $out_fastq ],
);
ok($trimmer, 'create trimmer');
isa_ok($trimmer, 'Genome::Model::Tools::FastQual::Trimmer::BwaStyle');
ok($trimmer->execute, 'execute trimmer');
is(File::Compare::compare($example_fastq, $out_fastq), 0, "fastq trimmed as expected");

done_testing();
exit;

#$HeadURL$
#$Id$
