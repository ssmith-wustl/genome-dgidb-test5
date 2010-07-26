use strict;
use warnings;

use above 'EGAP';

use Bio::Seq;
use Bio::SeqIO;

use File::Temp;
use File::Basename;
use Test::More tests => 12;

BEGIN {
    use_ok('GAP::Command');
    use_ok('GAP::Command::GenePredictor::RNAmmer');
}

my $command = GAP::Command::GenePredictor::RNAmmer->create(
                                                           'fasta_file' => File::Basename::dirname(__FILE__).'/data/Contig0a.masked.fasta',
                                                           'domain'     => 'eukaryota',
                                                          );

isa_ok($command, 'GAP::Command::GenePredictor');
isa_ok($command, 'GAP::Command::GenePredictor::RNAmmer');

SKIP: {
   skip "long test, semi redundant in calling from GAP modules, set RUNEGAP=1 to run", 8 unless $ENV{RUNEGAP};
ok($command->execute());

my @features = @{$command->bio_seq_feature()};

diag(scalar(@features). " features");
ok(@features > 0);

foreach my $feature (@features) {
    isa_ok($feature, 'Bio::SeqFeature::Generic');
}
}
