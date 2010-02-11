use strict;
use warnings;

use above 'GAP';

use Bio::Seq;
use Bio::SeqIO;

use File::Temp;
use Test::More tests => 42;

BEGIN {
    use_ok('GAP::Command');
    use_ok('GAP::Command::GenePredictor::tRNAscan');
}

my $command = GAP::Command::GenePredictor::tRNAscan->create(
                                                            'fasta_file' => 'data/Contig0a.masked.fasta',
                                                            'domain'     => 'eukaryota',
                                                           );

isa_ok($command, 'GAP::Command::GenePredictor');
isa_ok($command, 'GAP::Command::GenePredictor::tRNAscan');

ok($command->execute());

my @features = @{$command->bio_seq_feature()};

ok(@features > 0);

foreach my $feature (@features) {
    isa_ok($feature, 'Bio::SeqFeature::Generic');
}
