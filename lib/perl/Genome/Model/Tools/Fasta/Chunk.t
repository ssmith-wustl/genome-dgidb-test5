#!/usr/bin/env perl

use strict;
use warnings;

use above "Genome";
use Test::More tests => 2;
use File::Path;
use File::Temp;

BEGIN {
        use_ok ('Genome::Model::Tools::Fasta::Chunk');
}

my $dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Fasta/Chunk';
my $fasta_file = $dir .'/test.fasta';

my $tmp_dir = File::Temp::tempdir(
    "FastaChunk_XXXXXX", 
    DIR     => '/gsc/var/cache/testsuite/running_testsuites',
    CLEANUP => 1,
);

my $chunk = Genome::Model::Tools::Fasta::Chunk->create(
    fasta_file => $fasta_file,
    chunk_size => 2,
    chunk_dir  => $tmp_dir,
);

my $out = $chunk->execute;
ok($out, "fasta_chunk runs ok");

exit;

