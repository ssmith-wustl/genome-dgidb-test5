#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";
use Test::More tests => 2;
use File::Path;

BEGIN {
        use_ok ('Genome::Model::Tools::Fasta::Chunk');
}

my $dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Fasta/Chunk';
my $fasta_file = $dir .'/test.fasta';

my $chunk = Genome::Model::Tools::Fasta::Chunk->create(
    fasta_file => $fasta_file,
    chunk_size => 2,
);
my $chunk_dir = $chunk->chunk_dir;
my $out = $chunk->execute;
ok($out, "fasta_chunk runs ok");

rmtree $chunk_dir;

exit;

