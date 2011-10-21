package Genome::GeneName::Command::ConvertToEntrez;

use strict;
use warnings;
use Genome;
use List::MoreUtils qw/ uniq /; 

class Genome::GeneName::Command::ConvertToEntrez {
    is => 'Genome::Command::Base',
    has => [
        gene_identifier => {
            is => 'Text',
            shell_args_position => 1,
            doc => 'Gene identifiers to convert to entrez',
        },
        _entrez_gene_names => {
            is => 'Genome::GeneName',
            is_many => 1,
            is_output => 1,
            is_optional => 1,
            doc => 'Array of gene names produced as output',
        }
    ],
};

sub help_brief {
    'Translate a gene identifier to one or more Genome::GeneNames';
}

sub help_synopsis {
    'genome gene-name convert-to-entrez --gene-identifier ARK1D1';
}

sub help_detail {
    #TODO: write me
}

sub execute {
    my $self = shift;
    my $gene_identifier = $self->gene_identifier;
    my @entrez_gene_names = $self->convert_to_entrez_gene_name($gene_identifier);
    $self->_entrez_gene_names(\@entrez_gene_names);
    return 1;
}

sub convert_to_entrez_gene_name {
    my $self = shift;
    my $gene_identifier = shift;
    my @entrez_gene_names;

    #If the incoming gene identifier has a trailing version number, strip it off before comparison
    if ($gene_identifier =~ /(.*)\.\d+$/){
        $gene_identifier = $1;
    }

    @entrez_gene_names = $self->_match_as_entrez_gene_symbol($gene_identifier);

    unless(@entrez_gene_names){
        @entrez_gene_names = $self->_match_as_entrez_id($gene_identifier);
    }

    unless(@entrez_gene_names){
        @entrez_gene_names = $self->_match_as_ensembl_id($gene_identifier);
    }

    unless(@entrez_gene_names){
        @entrez_gene_names = $self->_match_as_uniprot_id($gene_identifier);
    }

    #TODO: last ditch effort here?

    return @entrez_gene_names;
}

sub _match_as_entrez_gene_symbol {
    my $self = shift;
    my $gene_identifier = shift;
    
    my @entrez_gene_name_associations = Genome::GeneNameAssociation->get(nomenclature => ['entrez_gene_symbol', 'entrez_gene_synonym'], alternate_name => $gene_identifier);
    my @gene_names = map($_->gene_name, @entrez_gene_name_associations);
    
    @gene_names = uniq @gene_names;
    return @gene_names;
}

sub _match_as_entrez_id {
    my $self = shift;
    my $gene_identifier = shift;

    my @entrez_gene_names = Genome::GeneName->get(nomenclature => 'entrez_id', name => $gene_identifier);
    return @entrez_gene_names;
}

sub _match_as_ensembl_id {
    my $self = shift;
    my $gene_identifier = shift;
    my @entrez_gene_names;

    my @gene_names = Genome::GeneName->get(source_db_name => 'Ensembl', name => $gene_identifier);
    for my $gene_name (@gene_names){
        my @identifiers = ($gene_name->name, map($_->alternate_name, $gene_name->gene_name_associations)); 
        for my $identifier (@identifiers){
            push @entrez_gene_names, $self->_match_as_entrez_gene_symbol($identifier);
        }
    }

    return @entrez_gene_names;
}

sub _match_as_uniprot_id {
    my $self = shift;
    my $gene_identifier = shift;

    my @gene_name_associations = Genome::GeneNameAssociation->get(nomenclature => 'uniprot_id', alternate_name => $gene_identifier);
    my @gene_names = map($_->gene_name, @gene_name_associations);
    @gene_names = uniq @gene_names;
    my @entrez_gene_names;
    for my $gene_name (@gene_names){
        my @identifiers = ($gene_name->name, map($_->alternate_name, grep($_->nomenclature ne 'uniprot_id', $gene_name->gene_name_associations))); 
        for my $identifier (@identifiers){
            push @entrez_gene_names, $self->_match_as_entrez_gene_symbol($identifier);
        }
    }
    
    @entrez_gene_names = uniq @entrez_gene_names;
    return @entrez_gene_names;
}

1;
