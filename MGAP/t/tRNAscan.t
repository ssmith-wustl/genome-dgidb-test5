use strict;
use warnings;

use Workflow;

use Bio::Seq;
use Bio::SeqIO;

use File::Temp;
use Test::More tests => 42;

BEGIN {
    use_ok('MGAP::Command');
    use_ok('MGAP::Command::GenePredictor::tRNAscan');
}

my $command = MGAP::Command::GenePredictor::tRNAscan->create(
                                                             'fasta_file' => 'data/HPAG1.fasta',
                                                            );

isa_ok($command, 'MGAP::Command::GenePredictor');
isa_ok($command, 'MGAP::Command::GenePredictor::tRNAscan');

ok($command->execute());

my @features = @{$command->bio_seq_feature()};

ok(@features > 0);

foreach my $feature (@features) {
    isa_ok($feature, 'Bio::SeqFeature::Generic');
}
