use strict;
use warnings;

use above 'EGAP';

use Bio::Seq;
use Bio::SeqIO;

use File::Temp 'tempdir';
use File::Basename;
use Test::More tests => 9;

BEGIN {
    use_ok('EGAP::Command');
    use_ok('EGAP::Command::GenePredictor::RNAmmer');
}

my $test_dir = "/gsc/var/cache/testsuite/running_testsuites/";
my $test_output_dir = tempdir('EGAP-Command-SNAP-XXXXXX',
    DIR => $test_dir,
    CLEANUP => 1,
    UNLINK => 1,
);
chmod(0755, $test_output_dir);
ok(-d $test_output_dir, "test output dir exists");

my $fasta = File::Basename::dirname(__FILE__).'/data/SCTG6.a_b.dna.masked.fasta';
ok(-e $fasta, "fasta file exists at $fasta");

my $seq_file = File::Basename::dirname(__FILE__).'/data/SCTG6.a_b.dna.masked.egap_sequence';
ok (-e $seq_file, "egap sequence file exists at $seq_file");

my $command = EGAP::Command::GenePredictor::RNAmmer->create(
    fasta_file => $fasta,
    raw_output_directory => $test_output_dir,
    rna_prediction_file => $test_output_dir . "/rna_predictions.csv",
    egap_sequence_file => $seq_file,
);

isa_ok($command, 'EGAP::Command::GenePredictor');
isa_ok($command, 'EGAP::Command::GenePredictor::RNAmmer');
ok($command->execute(), "executed rnammer command");

$DB::single = 1;
my @rna = EGAP::RNAGene->get(
    file_path => $command->rna_prediction_file,
);
my $num_rna = scalar @rna;
ok ($num_rna > 0, "able to retrieve $num_rna RNAGene objects");

