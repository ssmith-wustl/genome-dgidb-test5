use strict;
use warnings;

use above "MGAP";
use Workflow;

use Bio::Seq;
use Bio::SeqIO;

use File::Temp;
use File::Basename;
#use Test::More tests => 42;
use Test::More tests => 42;

BEGIN {
    use_ok('MGAP::Command');
    use_ok('MGAP::Command::GenePredictor::tRNAscan');
}

my $command = MGAP::Command::GenePredictor::tRNAscan->create(
                                                             'fasta_file' => File::Basename::dirname(__FILE__).'/data/HPAG1.fasta',
                                                             'domain' => 'bacteria',
                                                            );

isa_ok($command, 'MGAP::Command::GenePredictor');
isa_ok($command, 'MGAP::Command::GenePredictor::tRNAscan');

ok($command->execute());

my @features = @{$command->bio_seq_feature()};

ok(@features > 0);

foreach my $feature (@features) {
    isa_ok($feature, 'Bio::SeqFeature::Generic');
}

#done_testing();
