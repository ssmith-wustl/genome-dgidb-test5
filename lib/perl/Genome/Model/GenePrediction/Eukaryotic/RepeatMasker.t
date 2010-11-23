use strict;
use warnings;

use above 'Genome';

use Bio::Seq;
use Bio::SeqIO;
use File::Temp;
use File::Basename;
use Test::More;

BEGIN {
    use_ok('Genome::Model::GenePrediction::Eukaryotic::RepeatMasker');
}

my $test_data_dir = '/gsc/var/cache/testsuite/data/Genome-Model-GenePrediction-Eukaryotic/';
ok(-d $test_data_dir, "test data directory exists at $test_data_dir");

my $fasta_file = $test_data_dir . "shorter_ctg.dna";
ok(-e $fasta_file, "test fasta file found at $fasta_file");

my $repeat_library = '/gsc/var/lib/repeat/Trichinella_spiralis-3.7.1_070320.rep';
ok(-e $repeat_library, "found repeat library at $repeat_library");

my $command = Genome::Model::GenePrediction::Eukaryotic::RepeatMasker->create(
    fasta_file => $fasta_file, 
    repeat_library => $repeat_library,
    masked_fasta => '/tmp/repeat_masker_masked_fasta.fa',
);
isa_ok($command, 'Genome::Model::GenePrediction::Eukaryotic::RepeatMasker');

ok($command->execute(), 'execute');

my $seqio = Bio::SeqIO->new(
    -file => $command->masked_fasta(), 
    -format => 'Fasta'
);

while (my $seq = $seqio->next_seq()) {
    isa_ok($seq, 'Bio::SeqI');
}

done_testing();
