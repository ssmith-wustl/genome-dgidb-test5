use strict;
use warnings;

use above 'EGAP';

use Bio::Seq;
use Bio::SeqIO;

use File::Temp;
use File::Basename;
use Test::More tests => 1122;

BEGIN {
    use_ok('EGAP::Command');
    use_ok('EGAP::Command::GenePredictor::SNAP');
}

my $test_output_dir = "/gsc/var/cache/testsuite/running_testsuites/";

my $output_file = File::Temp->new(
    TEMPLATE => "EGAP-Command-GenePrediction-SNAP-XXXXXX",
    DIR => $test_output_dir
);

my $error_file = File::Temp->new(
    TEMPLATE => "EGAP-Command-GenePrediction-SNAP-XXXXXX",
    DIR => $test_output_dir
);

my $command = EGAP::Command::GenePredictor::SNAP->create(
    fasta_file => File::Basename::dirname(__FILE__).'/data/Contig0a.masked.fasta',
    hmm_file => '/gsc/pkg/bio/snap/installed/HMM/C.elegans.hmm',
    snap_output_file => $output_file->filename,
    snap_error_file => $error_file->filename,
);

isa_ok($command, 'EGAP::Command::GenePredictor');
isa_ok($command, 'EGAP::Command::GenePredictor::SNAP');

ok($command->execute());

my @features = @{$command->bio_seq_feature()};

ok(@features > 0);

foreach my $feature (@features) {
    isa_ok($feature, 'Bio::Tools::Prediction::Gene');
    ok(defined($feature->seq_id()));
    is($feature->seq_id(), 'TRISPI_Contig0.a');
}
