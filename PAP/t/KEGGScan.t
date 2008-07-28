use strict;
use warnings;

use Workflow;

use Bio::Seq;
use Bio::SeqIO;

use File::Temp;
use Test::More tests => 2112;

BEGIN {
    use_ok('BAP::Command');
    use_ok('BAP::Command::KEGGScan');
}

my $command = BAP::Command::KEGGScan->create('fasta_file' => 'data/HPAG1.fasta');
isa_ok($command, 'BAP::Command::KEGGScan');

ok($command->execute());
