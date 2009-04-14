#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";
use Test::More tests => 3;
use File::Compare;
use File::Temp;

BEGIN {
        use_ok ('Genome::Model::Tools::Fastq::ToPhdballScf');
}

my $dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Fastq/ToPhdballScf';
my $fastq_file = $dir .'/test.fq';
my $time = 'Mon Jan 10 20:00:00 2009';
my $scf_dir = $dir.'/chromat_dir';

my %params = (
    fastq_file => $fastq_file,
    scf_dir    => $scf_dir,
    ball_file  => $dir.'/phd.ball',
    id_range   => '1-33',
    base_fix   => 1,
    time       => $time,
    solexa_fastq => 1,
);

my $to_ballscf = Genome::Model::Tools::Fastq::ToPhdballScf->create(%params);

isa_ok($to_ballscf,'Genome::Model::Tools::Fastq::ToPhdballScf');
ok($to_ballscf->execute,'ToPhdballScf executes ok');

unlink $dir.'/phd.ball';
`rm -rf $scf_dir`;

exit;

