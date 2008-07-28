use strict;
use warnings;

use Workflow;

use Bio::Seq;
use Bio::SeqIO;

use File::Temp;
use Test::More tests => 2112;

BEGIN {
    use_ok('BAP::Command');
    use_ok('BAP::Command::BlastP');
}

my $command = BAP::Command::BlastP->create('fasta_file' => 'data/HPAG1.fasta');
isa_ok($command, 'BAP::Command::BlastP');

ok($command->execute());
