use strict;
use warnings;

use above 'EGAP';

use Bio::Seq;
use Bio::SeqIO;

use File::Temp 'tempdir';
use File::Basename;
#use Test::More skip_all => 'Takes an hour, regardless of input sequence size';
use Test::More tests => 11;

BEGIN {
    use_ok('EGAP::Command');
    use_ok('EGAP::Command::GenePredictor::RfamScan');
}

my $test_dir = "/gsc/var/cache/testsuite/running_testsuites/";
my $test_output_dir = tempdir('EGAP-Command-SNAP-XXXXXX',
    DIR => $test_dir,
    CLEANUP => 1,
    UNLINK => 1,
);
chmod(0755, $test_output_dir);
ok(-d $test_output_dir, "test output dir exists");

my $fasta = File::Basename::dirname(__FILE__).'/data/Contig0a.masked.fasta.short';
ok(-e $fasta, "fasta file exists at $fasta");

my $command = EGAP::Command::GenePredictor::RfamScan->create(
    fasta_file => File::Basename::dirname(__FILE__).'/data/Contig0a.masked.fasta',
    rna_prediction_file => $test_output_dir . "/rna_predictions.csv",
    raw_output_directory => $test_output_dir,
);

isa_ok($command, 'EGAP::Command::GenePredictor');
isa_ok($command, 'EGAP::Command::GenePredictor::RfamScan');

ok($command->execute(), "executed rfamscan command");

my @rna = EGAP::RNAGene->get(
    file_path => $command->rna_prediction_file
);
my $num_rna = scalar @rna;
ok($num_rna > 0, "able to retrieve $num_rna RNAGene objects");

