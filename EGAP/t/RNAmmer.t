use strict;
use warnings;

use above 'EGAP';

use Bio::Seq;
use Bio::SeqIO;

use File::Temp;
use Test::More tests => 12;

BEGIN {
    use_ok('GAP::Command');
    use_ok('GAP::Command::GenePredictor::RNAmmer');
}

my $command = GAP::Command::GenePredictor::RNAmmer->create(
                                                           'fasta_file' => 'data/Contig0a.masked.fasta',
                                                           'domain'     => 'eukaryota',
                                                          );

isa_ok($command, 'GAP::Command::GenePredictor');
isa_ok($command, 'GAP::Command::GenePredictor::RNAmmer');

ok($command->execute());

my @features = @{$command->bio_seq_feature()};

ok(@features > 0);

foreach my $feature (@features) {
    isa_ok($feature, 'Bio::SeqFeature::Generic');
}
