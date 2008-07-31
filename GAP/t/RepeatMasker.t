use strict;
use warnings;

use Workflow;

use Bio::Seq;
use Bio::SeqIO;

use File::Temp;
use Test::More tests => 12;

BEGIN {
    use_ok('GAP::Command');
    use_ok('GAP::Command::RepeatMasker');
}

my $temp_fh = File::Temp->new();
my $temp_fn = $temp_fh->filename();

$temp_fh->close();

my $command = GAP::Command::RepeatMasker->create(
                                                 'input_file'  => 'data/C_elegans.chrI.ws184.fasta.bz2',
                                                 'output_file' => $temp_fn,
                                                );
isa_ok($command, 'GAP::Command::RepeatMasker');

ok($command->execute(), 'execute');

my $seqio = Bio::SeqIO->new(-file => $temp_fn, -format => 'Fasta');

my $seq = $seqio->next_seq();

isa_ok($seq, 'Bio::SeqI');

warn $seq->length();
