#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";

use Test::More tests => 3;

BEGIN {
        use_ok('Genome::Model::Tools::Hgmi::MkPredictionModels');
}

my $fasta = "/tmp/disk/analysis/HGMI/B_catenulatum/Bifidobacterium_catenulatum_BIFCATDFT_1.0_newb/Version_1.0/Sequence/Unmasked/BIFCATDFT.v1.contigs.newname.fasta";
my $m = Genome::Model::Tools::Hgmi::MkPredictionModels->create(
            'locus_tag_prefix' => "BIFCATDFT",
            'fasta_file' => $fasta,

);

isa_ok($m,'Genome::Model::Tools::Hgmi::MkPredictionModels');


ok($m->execute(),'create models');
