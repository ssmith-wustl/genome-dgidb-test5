#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";
use Test::More tests => 3;
use File::Compare;
use File::Temp;

BEGIN {
        use_ok ('Genome::Model::Tools::Fastq::ToPhdballScf::Chunk');
}

my $dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Fastq/ToPhdballScf_Chunk';
my $fastq_file = $dir .'/test.fq';
my $time = 'Mon Jan 10 20:00:00 2009';
my $scf_dir = $dir.'/chromat_dir';

my %params = (
    fastq_file => $fastq_file,
    scf_dir    => $scf_dir,
    ball_file  => $dir.'/phd.ball',
    base_fix   => 1,
    time       => $time,
    chunk_size => 10,
);

my $to_ballscf = Genome::Model::Tools::Fastq::ToPhdballScf::Chunk->create(%params);

isa_ok($to_ballscf,'Genome::Model::Tools::Fastq::ToPhdballScf::Chunk');
ok($to_ballscf->execute,'ToPhdballScf_Chunk executes ok');

unlink $dir.'/phd.ball';
`rm -rf $scf_dir`;

exit;

