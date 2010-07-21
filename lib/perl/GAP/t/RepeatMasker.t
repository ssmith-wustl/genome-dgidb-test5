use strict;
use warnings;

use above 'GAP';

use Bio::Seq;
use Bio::SeqIO;

use File::Temp;
use Test::More tests => 12;

BEGIN {
    use_ok('GAP::Command');
    use_ok('GAP::Command::RepeatMasker');
}


my $command = GAP::Command::RepeatMasker->create(
                                                 'input_file'     => 'data/BACSTEFNL_Contig694.fasta',
                                                 'repeat_library' => '/gsc/var/lib/repeat/Trichinella_pseudospiralis_1.0_080103.rep', 
                                                );
isa_ok($command, 'GAP::Command::RepeatMasker');

ok($command->execute(), 'execute');

my $seqio = Bio::SeqIO->new(-file => $command->output_file(), -format => 'Fasta');

my $seq = $seqio->next_seq();

isa_ok($seq, 'Bio::SeqI');
