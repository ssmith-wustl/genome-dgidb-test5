use strict;
use warnings;

use above 'EGAP';

use Bio::Seq;
use Bio::SeqIO;

use File::Temp;
use Test::More tests => 1122;

BEGIN {
    use_ok('EGAP::Command');
    use_ok('EGAP::Command::GenePredictor::SNAP');
}

my $command = EGAP::Command::GenePredictor::SNAP->create(
                                                         'fasta_file' => 'data/Contig0a.masked.fasta',
                                                         'hmm_file'   => '/gsc/pkg/bio/snap/installed/HMM/C.elegans.hmm' 
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
