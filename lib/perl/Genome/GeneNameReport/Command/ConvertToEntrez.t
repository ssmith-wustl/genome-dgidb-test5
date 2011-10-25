#!/gsc/bin/perl

use strict;
use warnings;
use above "Genome";

use Test::More tests => 9;

$ENV{UR_DBI_NO_COMMIT} = 1;
$ENV{USE_DUMMY_AUTOGENERATED_IDS} = 1;

use_ok('Genome::GeneNameReport::Command::ConvertToEntrez');

SKIP: {
    skip "Test data has been blown away, reenable on new import", 8;
    my $entrez_gene_symbol_cmd = Genome::GeneNameReport::Command::ConvertToEntrez->execute(gene_identifier => 'AKR1D1');
    ok($entrez_gene_symbol_cmd->_entrez_gene_name_reports, 'Found entrez_gene_symbol: AKR1D1');
    ok(!$entrez_gene_symbol_cmd->_intermediate_gene_name_reports, 'No intermediate_gene_name_reports for AKR1D1');

    my $entrez_id_cmd = Genome::GeneNameReport::Command::ConvertToEntrez->execute(gene_identifier => '26157');
    ok($entrez_id_cmd->_entrez_gene_name_reports, 'Found entrez_gene_id: 26157');
    ok(!$entrez_id_cmd->_intermediate_gene_name_reports, 'No intermediate_gene_name_reports for 26157');

    my $ensembl_id_cmd = Genome::GeneNameReport::Command::ConvertToEntrez->execute(gene_identifier => 'ENSG00000189114');
    ok($ensembl_id_cmd->_entrez_gene_name_reports, 'Found ensembl_id: ENSG00000189114');
    ok(!$ensembl_id_cmd->_intermediate_gene_name_reports, 'No intermediate_gene_name_reports for ENSG00000189114');

    my $uniprot_id_cmd = Genome::GeneNameReport::Command::ConvertToEntrez->execute(gene_identifier => 'P51857');
    ok($uniprot_id_cmd->_entrez_gene_name_reports, 'Found uniprot_id: P51857');
    ok($uniprot_id_cmd->_intermediate_gene_name_reports, 'Intermediate_gene_name_reports for P51857');
};
