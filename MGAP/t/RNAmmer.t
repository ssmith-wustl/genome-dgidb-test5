use strict;
use warnings;

use Workflow;

use Bio::Seq;
use Bio::SeqIO;

use File::Temp;
use Test::More tests => 12;

BEGIN {
    use_ok('MGAP::Command');
    use_ok('MGAP::Command::GenePredictor::RNAmmer');
}

my $command = MGAP::Command::GenePredictor::RNAmmer->create(
                                                            'fasta_file' => 'data/HPAG1.fasta',
                                                           );

isa_ok($command, 'MGAP::Command::GenePredictor');
isa_ok($command, 'MGAP::Command::GenePredictor::RNAmmer');

ok($command->execute());

my @features = @{$command->bio_seq_feature()};

ok(@features > 0);

foreach my $feature (@features) {
    isa_ok($feature, 'Bio::SeqFeature::Generic');
}
