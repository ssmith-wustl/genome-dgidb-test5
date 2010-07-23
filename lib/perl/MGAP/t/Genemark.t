use strict;
use warnings;

use above "MGAP";
use Workflow;

use Bio::Seq;
use Bio::SeqIO;

use File::Temp;
use File::Basename;
use Test::More tests => 1525; # orig 1615?

BEGIN {
    use_ok('MGAP::Command');
    use_ok('MGAP::Command::GenePredictor::Genemark');
}

my $command = MGAP::Command::GenePredictor::Genemark->create(
                                                             'fasta_file' => File::Basename::dirname(__FILE__).'/data/HPAG1.fasta',
                                                             'gc_percent' => 39.1, 
                                                            );

isa_ok($command, 'MGAP::Command::GenePredictor');
isa_ok($command, 'MGAP::Command::GenePredictor::Genemark');

ok($command->execute());

ok($command->model_file =~ /heu_11_39\.mod$/);

my @features = @{$command->bio_seq_feature()};

ok(@features > 0);

foreach my $feature (@features) {
    isa_ok($feature, 'Bio::SeqFeature::Generic');
}
