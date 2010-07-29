use strict;
use warnings;

use above 'GAP';

use Bio::Seq;
use Bio::SeqIO;

use File::Temp;
use File::Basename;
use Test::More tests => 42;

BEGIN {
    use_ok('GAP::Command');
    use_ok('GAP::Command::GenePredictor::tRNAscan');
}

my $command = GAP::Command::GenePredictor::tRNAscan->create(
                                                            'fasta_file' => File::Basename::dirname(__FILE__).'/data/Contig0a.masked.fasta',
                                                            'domain'     => 'eukaryota',
                                                           );

isa_ok($command, 'GAP::Command::GenePredictor');
isa_ok($command, 'GAP::Command::GenePredictor::tRNAscan');

SKIP: {
    skip "long test, somewhat redundant in calling from GAP, set RUNEGAP=1", 38 unless $ENV{RUNEGAP};
ok($command->execute());

my @features = @{$command->bio_seq_feature()};
diag(scalar(@features)." features");
ok(@features > 0);

foreach my $feature (@features) {
    isa_ok($feature, 'Bio::SeqFeature::Generic');
}
}
