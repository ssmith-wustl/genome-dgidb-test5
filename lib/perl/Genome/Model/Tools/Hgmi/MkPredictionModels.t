#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";
use File::Remove qw/ remove /;
use Test::More tests => 6;

BEGIN {
        use_ok('Genome::Model::Tools::Hgmi::MkPredictionModels');
}

my $testdir = "/gsc/var/cache/testsuite/data/Genome-Model-Tools-Hgmi/";
my $fasta = $testdir."/"."BIFCATDFT.v1.contigs.newname.fasta";
chdir($testdir);

my $m = Genome::Model::Tools::Hgmi::MkPredictionModels->create(
            'locus_tag' => "BIFCATDFT",
            'fasta_file' => $fasta,
);

isa_ok($m,'Genome::Model::Tools::Hgmi::MkPredictionModels');

remove \1, qw{ /gsc/var/cache/testsuite/data/Genome-Model-Tools-Hgmi/BIFCATDFT_gl3.icm /gsc/var/cache/testsuite/data/Genome-Model-Tools-Hgmi/BIFCATDFT_gl3.motif /gsc/var/cache/testsuite/data/Genome-Model-Tools-Hgmi/heu_11_56.mod };
ok($m->execute(),'create models');
remove \1, qw{ /gsc/var/cache/testsuite/data/Genome-Model-Tools-Hgmi/BIFCATDFT_gl3.icm /gsc/var/cache/testsuite/data/Genome-Model-Tools-Hgmi/BIFCATDFT_gl3.motif /gsc/var/cache/testsuite/data/Genome-Model-Tools-Hgmi/heu_11_56.mod };

is($m->gc(), 56);

$fasta = $testdir."/"."BIFCATDFT.v1.contigs.newname.57gc.fasta";

$m = Genome::Model::Tools::Hgmi::MkPredictionModels->create(
            'locus_tag' => "BIFCATDFT",
            'fasta_file' => $fasta,
);

remove \1, qw{ /gsc/var/cache/testsuite/data/Genome-Model-Tools-Hgmi/BIFCATDFT_gl3.icm /gsc/var/cache/testsuite/data/Genome-Model-Tools-Hgmi/BIFCATDFT_gl3.motif /gsc/var/cache/testsuite/data/Genome-Model-Tools-Hgmi/heu_11_59.mod };
ok($m->execute(),'create models');
remove \1, qw{ /gsc/var/cache/testsuite/data/Genome-Model-Tools-Hgmi/BIFCATDFT_gl3.icm /gsc/var/cache/testsuite/data/Genome-Model-Tools-Hgmi/BIFCATDFT_gl3.motif /gsc/var/cache/testsuite/data/Genome-Model-Tools-Hgmi/heu_11_59.mod };

is($m->gc(), 59);
