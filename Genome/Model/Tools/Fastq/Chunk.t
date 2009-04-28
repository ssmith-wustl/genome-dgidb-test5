#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";
use Test::More tests => 13;
use File::Path;
use File::Compare;
use File::Basename;

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

for my $chunk_file (glob("$chunk_dir/*.fastq")) {
    my $name = basename $chunk_file;
    my $ori_file = $dir."/ori_chunk_dir/$name";
    cmp_ok(compare($chunk_file, $ori_file), '==', 0, "Chunk file $name matches original as expected");
}

rmtree $chunk_dir;

my $fast_chunk = Genome::Model::Tools::Fastq::Chunk->create(
    fastq_file => $fastq_file,
    chunk_size => 50,
    fast_mode  => 1,
);
$chunk_dir = $fast_chunk->chunk_dir;
$out = $fast_chunk->execute;
ok($out, "fastq_chunk with fast mode runs ok");

for my $chunk_file (glob("$chunk_dir/*.fastq")) {
    my $name = basename $chunk_file;
    my $ori_file = $dir."/ori_chunk_dir/$name";
    cmp_ok(compare($chunk_file, $ori_file), '==', 0, "Chunk file $name matches original as expected");
}
rmtree $chunk_dir;


exit;

