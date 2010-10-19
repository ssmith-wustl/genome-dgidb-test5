use strict;
use warnings;

use above 'EGAP';

use Bio::Seq;
use Bio::SeqIO;

use File::Temp qw(tempdir);
use File::Basename;
use Test::More tests => 11;

BEGIN {
    use_ok('EGAP::Command');
    use_ok('EGAP::Command::GenePredictor::SNAP');
}

my $test_dir = "/gsc/var/cache/testsuite/running_testsuites/";
my $test_output_dir = tempdir('EGAP-Command-SNAP-XXXXXX',
    DIR => $test_dir,
    CLEANUP => 1,
    UNLINK => 1,
);
chmod(0755, $test_output_dir);

my $fasta = File::Basename::dirname(__FILE__).'/data/Contig0a.masked.fasta';
ok(-e $fasta, "fasta file exists at $fasta");

my $model = '/gsc/pkg/bio/snap/installed/HMM/C.elegans.hmm';
ok(-e $model, "model file exists at $model");

my $command = EGAP::Command::GenePredictor::SNAP->create(
    fasta_file => $fasta,
    model_files => $model, 
    coding_gene_prediction_file => $test_output_dir . "/coding_genes.csv",
    transcript_prediction_file => $test_output_dir . "/transcripts.csv",
    exon_prediction_file => $test_output_dir . "/exons.csv",
    protein_prediction_file => $test_output_dir . "/proteins.csv",
    version => '2010-07-28',
    raw_output_directory => $test_output_dir,
);

isa_ok($command, 'EGAP::Command::GenePredictor');
isa_ok($command, 'EGAP::Command::GenePredictor::SNAP');

ok($command->execute(), "executed snap command");

my @genes = EGAP::CodingGene->get(
    file_path => $command->coding_gene_prediction_file
);
my $num_genes = scalar @genes;
ok($num_genes > 0, "able to retrieve $num_genes coding gene objects");

my @proteins = EGAP::Protein->get(
    file_path => $command->protein_prediction_file
);
my $num_proteins = scalar @proteins;
ok($num_proteins > 0, "able to retrieve $num_proteins protein objects");

my @transcripts = EGAP::Transcript->get(
    file_path => $command->transcript_prediction_file,
);
my $num_transcripts = scalar @transcripts;
ok($num_transcripts > 0, "able to retrieve $num_transcripts transcript objects");

my @exons = EGAP::Exon->get(
    file_path => $command->exon_prediction_file,
);
my $num_exons = scalar @exons;
ok($num_exons > 0, "able to retrieve $num_exons exon objects");


system("cp " . $command->exon_prediction_file . " ~");
system("cp " . $command->coding_gene_prediction_file . " ~");
