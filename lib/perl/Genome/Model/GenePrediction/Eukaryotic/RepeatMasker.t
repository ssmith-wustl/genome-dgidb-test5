use strict;
use warnings;

use above 'Genome';

use Bio::Seq;
use Bio::SeqIO;
use File::Temp 'tempdir';
use File::Basename;
use Test::More tests => 8;

BEGIN {
    use_ok('Genome::Model::GenePrediction::Eukaryotic::RepeatMasker');
}

my $test_data_dir = '/gsc/var/cache/testsuite/data/Genome-Model-GenePrediction-Eukaryotic/';
ok(-d $test_data_dir, "test data directory exists at $test_data_dir");

my $fasta_file = $test_data_dir . "shorter_ctg.dna";
ok(-e $fasta_file, "test fasta file found at $fasta_file");

my $repeat_library = '/gsc/var/lib/repeat/Trichinella_spiralis-3.7.1_070320.rep';
ok(-e $repeat_library, "found repeat library at $repeat_library");

my $temp_dir = tempdir(
    '/gsc/var/cache/testsuite/running_testsuites/Genome-Model-GenePrediction-Eukaryotic-RepeatMasker-XXXXXX',
    CLEANUP => 1,
    UNLINK => 1,
);
my $masked_fasta = File::Temp->new(
    TEMPLATE => 'repeat_masker_masked_fasta_XXXXXX',
    DIR => $temp_dir,
    UNLINK => 1,
    CLEANUP => 1,
);
my $ace_file = File::Temp->new(
    TEMPLATE => 'repeat_masker_ace_file_XXXXXX',
    DIR => $temp_dir,
    UNLINK => 1,
    CLEANUP => 1,
);

my $command = Genome::Model::GenePrediction::Eukaryotic::RepeatMasker->create(
    fasta_file => $fasta_file, 
    repeat_library => $repeat_library,
    masked_fasta => $masked_fasta->filename,
    make_ace => 1,
    ace_file_location => $ace_file->filename,
);

isa_ok($command, 'Genome::Model::GenePrediction::Eukaryotic::RepeatMasker');
ok($command->execute(), 'execute');
ok(-s $command->masked_fasta, 'data written to masked fasta');
ok(-s $command->ace_file_location, 'data written to ace file');

