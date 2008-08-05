use strict;
use warnings;

use Workflow;

use Bio::Seq;
use Bio::SeqIO;

use File::Temp;
use Test::More tests => 5;

BEGIN {
    use_ok('PAP::Command');
    use_ok('PAP::Command::BlastP');
}

my $command = PAP::Command::BlastP->create('fasta_file' => 'data/B_coprocola.chunk.fasta');
isa_ok($command, 'PAP::Command::BlastP');

ok($command->execute());

my $ref = $command->bio_seq_feature();

is(ref($ref), 'ARRAY');
