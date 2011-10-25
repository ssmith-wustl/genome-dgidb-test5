package Genome::GeneNameReport::Command::ConvertToEntrez;

use strict;
use warnings;
use Genome;
use List::MoreUtils qw/ uniq /;

class Genome::GeneNameReport::Command::ConvertToEntrez {
    is => 'Genome::Command::Base',
    has => [
        gene_identifier => {
            is => 'Text',
            shell_args_position => 1,
            doc => 'Gene identifiers to convert to entrez',
        },
        _entrez_gene_name_reports => {
            is => 'Genome::GeneNameReport',
            is_many => 1,
            is_output => 1,
            is_optional => 1,
            doc => 'Array of gene name reports produced as output',
        },
        _intermediate_gene_name_reports => {
            is => 'Genome::GeneNameReport',
            is_many => 1,
            is_output => 1,
            is_optional => 1,
            doc => 'Array of gene name reports that were used to create _entrez_gene_name_reports',
        },
    ],
};

sub help_brief {
    'Translate a gene identifier to one or more Genome::GeneNameReports';
}

sub help_synopsis {
    'genome gene-name-report convert-to-entrez --gene-identifier ARK1D1';
}

sub help_detail {
    #TODO: write me
}

sub execute {
    my $self = shift;
    my $gene_identifier = $self->gene_identifier;
    my @entrez_gene_name_reports = $self->convert_to_entrez_gene_name_report($gene_identifier);
    $self->_entrez_gene_name_reports(\@entrez_gene_name_reports);
    return 1;
}

sub convert_to_entrez_gene_name_report {
    my $self = shift;
    my $gene_identifier = shift;
    my @entrez_gene_name_reports;

    #If the incoming gene identifier has a trailing version number, strip it off before comparison
    if ($gene_identifier =~ /(.*)\.\d+$/){
        $gene_identifier = $1;
    }

    @entrez_gene_name_reports = $self->_match_as_entrez_gene_symbol($gene_identifier);

    unless(@entrez_gene_name_reports){
        @entrez_gene_name_reports = $self->_match_as_entrez_id($gene_identifier);
    }

    unless(@entrez_gene_name_reports){
        @entrez_gene_name_reports = $self->_match_as_ensembl_id($gene_identifier);
    }

    unless(@entrez_gene_name_reports){
        @entrez_gene_name_reports = $self->_match_as_uniprot_id($gene_identifier);
    }

    #TODO: last ditch effort here?

    return @entrez_gene_name_reports;
}

sub _match_as_entrez_gene_symbol {
    my $self = shift;
    my $gene_identifier = shift;

    my @entrez_gene_name_report_associations = Genome::GeneNameReportAssociation->get(nomenclature => ['entrez_gene_symbol', 'entrez_gene_synonym'], alternate_name => $gene_identifier);
    my @gene_name_reports = map($_->gene_name_report, @entrez_gene_name_report_associations);

    @gene_name_reports = uniq @gene_name_reports;
    return @gene_name_reports;
}

sub _match_as_entrez_id {
    my $self = shift;
    my $gene_identifier = shift;

    my @entrez_gene_name_reports = Genome::GeneNameReport->get(nomenclature => 'entrez_id', name => $gene_identifier);
    return @entrez_gene_name_reports;
}

sub _match_as_ensembl_id {
    my $self = shift;
    my $gene_identifier = shift;
    my @entrez_gene_name_reports;

    my @gene_name_reports = Genome::GeneNameReport->get(source_db_name => 'Ensembl', name => $gene_identifier);
    for my $gene_name_report (@gene_name_reports){
        my @identifiers = ($gene_name_report->name, map($_->alternate_name, $gene_name_report->gene_name_report_associations));
        for my $identifier (@identifiers){
            push @entrez_gene_name_reports, $self->_match_as_entrez_gene_symbol($identifier);
        }
    }

    return @entrez_gene_name_reports;
}

sub _match_as_uniprot_id {
    my $self = shift;
    my $gene_identifier = shift;

    my @gene_name_report_associations = Genome::GeneNameReportAssociation->get(nomenclature => 'uniprot_id', alternate_name => $gene_identifier);
    my @gene_name_reports = map($_->gene_name_report, @gene_name_report_associations);
    @gene_name_reports = uniq @gene_name_reports;
    $self->_intermediate_gene_name_reports(\@gene_name_reports);
    my @entrez_gene_name_reports;
    for my $gene_name_report (@gene_name_reports){
        my @identifiers = ($gene_name_report->name, map($_->alternate_name, grep($_->nomenclature ne 'uniprot_id', $gene_name_report->gene_name_report_associations)));
        for my $identifier (@identifiers){
            push @entrez_gene_name_reports, $self->_match_as_entrez_gene_symbol($identifier);
        }
    }

    @entrez_gene_name_reports = uniq @entrez_gene_name_reports;
    return @entrez_gene_name_reports;
}

1;
