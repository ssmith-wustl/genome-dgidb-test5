#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";
use File::Remove qw/ remove /;
use Test::More tests => 3;

BEGIN {
        use_ok('Genome::Model::Tools::Hgmi::MkPredictionModels');
}

#my $fasta = "/tmp/disk/analysis/HGMI/B_catenulatum/Bifidobacterium_catenulatum_BIFCATDFT_1.0_newb/Version_1.0/Sequence/Unmasked/BIFCATDFT.v1.contigs.newname.fasta";
my $testdir = "/gsc/var/cache/testsuite/data/Genome-Model-Tools-Hgmi/";
my $fasta = $testdir."/"."BIFCATDFT.v1.contigs.newname.fasta";
chdir($testdir);

my $m = Genome::Model::Tools::Hgmi::MkPredictionModels->create(
            'locus_tag_prefix' => "BIFCATDFT",
            'fasta_file' => $fasta,
);

isa_ok($m,'Genome::Model::Tools::Hgmi::MkPredictionModels');

remove \1, qw{ /gsc/var/cache/testsuite/data/Genome-Model-Tools-Hgmi/BIFCATDFT_gl3.icm /gsc/var/cache/testsuite/data/Genome-Model-Tools-Hgmi/BIFCATDFT_gl3.motif /gsc/var/cache/testsuite/data/Genome-Model-Tools-Hgmi/heu_11_55.mod };
ok($m->execute(),'create models');
remove \1, qw{ /gsc/var/cache/testsuite/data/Genome-Model-Tools-Hgmi/BIFCATDFT_gl3.icm /gsc/var/cache/testsuite/data/Genome-Model-Tools-Hgmi/BIFCATDFT_gl3.motif /gsc/var/cache/testsuite/data/Genome-Model-Tools-Hgmi/heu_11_55.mod };

