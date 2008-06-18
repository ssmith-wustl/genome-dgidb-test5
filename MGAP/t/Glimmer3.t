use strict;
use warnings;

use Workflow;

use Bio::Seq;
use Bio::SeqIO;

use File::Temp;
use Test::More tests => 1616;

BEGIN {
    use_ok('MGAP::Command');
    use_ok('MGAP::Command::GenePredictor::Glimmer3');
}

my $command = MGAP::Command::GenePredictor::Glimmer3->create(
                                                             'fasta_file' => 'data/HPAG1.fasta',
                                                             'model_file' => 'data/HPAG1.glimmer3.icm',
                                                             'pwm_file'   => 'data/HPAG1.glimmer3.pwm',
                                                            );

isa_ok($command, 'MGAP::Command::GenePredictor');
isa_ok($command, 'MGAP::Command::GenePredictor::Glimmer3');

ok($command->execute());

my @features = @{$command->bio_seq_feature()};

ok(@features > 0);

foreach my $feature (@features) {
    isa_ok($feature, 'Bio::SeqFeature::Generic');
}
