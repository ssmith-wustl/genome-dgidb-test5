#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";
use Test::More tests => 2;
use File::Path;

BEGIN {
        use_ok ('Genome::Model::Tools::Fastq::Chunk');
}

my $dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Fastq/Chunk';
my $fastq_file = $dir .'/test.fq';

my $chunk = Genome::Model::Tools::Fastq::Chunk->create(
    fastq_file => $fastq_file,
    chunk_size => 50,
);
my $chunk_dir = $chunk->chunk_dir;
my $out = $chunk->execute;
ok($out, "fastq_chunk runs ok");

rmtree $chunk_dir;

exit;

