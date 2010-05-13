#!/gsc/bin/perl

use strict;
use warnings;

use Test::More tests => 4;

use above 'Genome';

use_ok('Genome::Model::Tools::Kmer::FastqPlotComplexity');
my $tmp_dir = File::Temp::tempdir('Genome-Model-Tools-Kmer-FastqPlotComplexity-'. $ENV{USER} .'-XXXX', DIR => '/gsc/var/cache/testsuite/running_testsuites', CLEANUP => 1);
my $data_dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Kmer-FastqPlotComplexity';
my $read_1_fastq = $data_dir .'/s_7_1_sequence.txt';
my $read_2_fastq = $data_dir .'/s_7_2_sequence.txt';

my $plot_complexity = Genome::Model::Tools::Kmer::FastqPlotComplexity->create(
    fastq_files => $read_1_fastq .','. $read_2_fastq,
    output_directory => $tmp_dir,
);
isa_ok($plot_complexity,'Genome::Model::Tools::Kmer::FastqPlotComplexity');
ok($plot_complexity->execute,'execute command '. $plot_complexity->command_name);
ok(-s $plot_complexity->plot_file,'Found plot file '. $plot_complexity->plot_file);
exit;

