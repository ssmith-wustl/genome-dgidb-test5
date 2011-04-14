#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Data::Dumper 'Dumper';
require File::Compare;
require File::Temp;
use Test::More;

use_ok('Genome::Model::Tools::FastQual') or die;

# Fake class to test cuz this class is abstract
class Genome::Model::Tools::FastQual::Tester {
    is => 'Genome::Model::Tools::FastQual',
};
sub Genome::Model::Tools::FastQual::Tester::execute {
    my $self = shift;

    # test opening readers /writers
    my $fastq_reader = $self->_open_reader;
    ok($fastq_reader, 'opened reader for fastq files') or die;
    isa_ok($fastq_reader, 'Genome::Model::Tools::FastQual::FastqReader');
    is($self->type_in, 'sanger', 'type in is sanger');
    my $fastq_writer = $self->_open_writer;
    ok($fastq_writer, 'opened writer for fastq files') or die;
    isa_ok($fastq_writer, 'Genome::Model::Tools::FastQual::FastqWriter');

    # write one fastq
    $fastq_writer->write( $fastq_reader->next );

    return 1;
}

# Files
my $dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-FastQual';
my $example_in_file = $dir.'/fast_qual.example.fastq';
my $example_out_file = $dir.'/fast_qual.example.fastq';
ok(-s $example_out_file, 'example out fastq file exists');
my $example_metrics_file = $dir.'/fast_qual.example.metrics';
ok(-s $example_metrics_file, 'example metrics file exists');
my $tmpdir = File::Temp::tempdir(CLEANUP => 1);
my $out_file = $tmpdir.'/out.fastq';
my $out2_file = $tmpdir.'/out2.fastq';
my $metrics_file = $tmpdir.'/metrics.txt';
my $metrics2_file = $tmpdir.'/metrics2.txt';

# Create and execute
my $fastq_tester = Genome::Model::Tools::FastQual->create(
    #input => [ $dir.'/big.fastq' ],
    input => [ $example_in_file ],
    output => [ $out_file ],
    metrics_file_out => $metrics_file,
);
ok($fastq_tester, 'create w/ fastq files');
ok($fastq_tester->execute, 'execute');
is(File::Compare::compare($out_file, $example_out_file), 0, 'output file ok');
is(File::Compare::compare($metrics_file, $example_metrics_file), 0, 'metrics file ok');

# Create and execute, again making sure metrcis are not stomped on
my $fastq_tester2 = Genome::Model::Tools::FastQual->create(
    input => [ $example_in_file ],
    output => [ $out2_file ],
    metrics_file_out => $metrics2_file,
);
ok($fastq_tester2, 'create again to test metrics are not stomping on each other');
ok($fastq_tester2->execute, 'execute');
is(File::Compare::compare($out2_file, $example_out_file), 0, 'output 2 file ok');
is(File::Compare::compare($metrics2_file, $example_metrics_file), 0, 'metrics 2 file ok');

# Test pipes
my $pipe_tester = Genome::Model::Tools::FastQual->create();
ok($pipe_tester, 'create w/ pipes');
#my $pipe_writer = $pipe_tester->_open_writer;
#ok($pipe_writer, 'opened writer for pipes') or die;
#isa_ok($pipe_writer, 'Genome::Utility::IO::StdoutRefWriter');
my $rv;
eval{
    $rv = $pipe_tester->_open_reader;
};
diag("\n".$@);
ok((!$rv && $@ =~ /No pipe meta info/), 'failed to open reader b/c no meta info');

#print "$tmpdir\n"; <STDIN>;
done_testing();
exit;
    
