use strict;
use warnings;

use Workflow;

use Bio::Seq;
use Bio::SeqIO;

use File::Temp;
use Test::More tests => 464;

BEGIN {
    use_ok('PAP::Command');
    use_ok('PAP::Command::FastaChunker');
}

my $command = PAP::Command::FastaChunker->create(
                                                'fasta_file' => 'data/B_coprocola.fasta',
                                                'chunk_size' => 10,
                                                );
isa_ok($command, 'PAP::Command::FastaChunker');

ok($command->execute());

my @files = @{$command->fasta_files()};

ok(scalar(@files) == 457);

my $seq_count;

foreach my $file (@files) {

    $seq_count = 0;

    my $seqin = Bio::SeqIO->new(-file => $file, -format => 'Fasta');

    while (my $seq = $seqin->next_seq()) {
        $seq_count++;
    }

    ok($seq_count <= 10);
    
}

is($seq_count, 7);

ok(unlink(@files) == 457);

