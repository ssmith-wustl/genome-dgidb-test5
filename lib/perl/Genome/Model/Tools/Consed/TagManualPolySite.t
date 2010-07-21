#!/gsc/bin/perl
use strict;
use warnings;
use above 'Genome';

use Test::More tests => 7;

use_ok('Genome::Model::Tools::Consed::TagManualPolySite');
my $ace_file = "/gsc/var/cache/testsuite/data/Genome-Model-Tools-Consed-TagManualPolySite/AML_Validation_22_Trios-H_20_00jlH-Ensembl.ace";
ok (-f $ace_file);
my $tag_ace = "$ace_file.tag";
`cp $ace_file $tag_ace`;
ok (-f "$tag_ace");
my $refseq_fasta = "/gscmnt/sata420/info/testsuite_data/Genome-Model-Tools-Consed-TagManualPolySite/AML_Validation_22_Trios-H_20_00jlH-Ensembl.c1.refseq.fasta";
ok (-f $refseq_fasta);
my $polyscan_file = "/gscmnt/sata420/info/testsuite_data/Genome-Model-Tools-Consed-TagManualPolySite/AML_Validation_22_Trios-H_20_00jlH-Ensembl.polyscan";
ok (-f $polyscan_file);
my $snp_gff = "/gscmnt/sata420/info/testsuite_data/Genome-Model-Tools-Consed-TagManualPolySite/AML_Validation_22_Trios-H_20_00jlH-Ensembl.snp.gff";
if (-f $snp_gff) {`rm $snp_gff`;}
my $force_file = "/gscmnt/sata420/info/testsuite_data/Genome-Model-Tools-Consed-TagManualPolySite/force_file";
ok (-f $force_file);

my ($info) = Genome::Model::Tools::Consed::TagManualPolySite->execute(ace_file => $tag_ace, refseq_fasta => $refseq_fasta, force_genotype_coords => $force_file, polyscan_snp => $polyscan_file, snp_gff => $snp_gff);

ok ($info);
