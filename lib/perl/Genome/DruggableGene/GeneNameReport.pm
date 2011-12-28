package Genome::DruggableGene::GeneNameReport;

use strict;
use warnings;

use Genome;
use List::MoreUtils qw/ uniq /;

class Genome::DruggableGene::GeneNameReport {
    is => 'UR::Object',
    id_generator => '-uuid',
    table_name => 'dgidb.gene_name_report',
    schema_name => 'dgidb',
    data_source => 'Genome::DataSource::Main',
    id_by => [
        id => {is => 'Text'},
    ],
    has => [
        name => { is => 'Text'},
        nomenclature => { is => 'Text'},
        source_db_name => { is => 'Text'},
        source_db_version => { is => 'Text'},
        description => {
            is => 'Text',
            is_optional => 1,
        },
        gene_name_report_associations => {
            is => 'Genome::DruggableGene::GeneNameReportAssociation',
            reverse_as => 'gene_name_report',
            is_many => 1,
        },
        alternate_names => {
            via => 'gene_name_report_associations',
            to => 'alternate_name',
            is_many => 1,
        },
        gene_name_report_category_associations => {
            is => 'Genome::DruggableGene::GeneNameReportCategoryAssociation',
            reverse_as => 'gene_name_report',
            is_many => 1,
        },
        drug_gene_interaction_reports => {
            is => 'Genome::DruggableGene::DrugGeneInteractionReport',
            reverse_as => 'gene_name_report',
            is_many => 1,
        },
        drug_name_reports => {
            is => 'Genome::DruggableGene::DrugNameReport',
            via => 'drug_gene_interaction_reports',
            to => 'drug_name_report',
            is_many => 1,
        },
        citation => {
            calculate_from => ['source_db_name', 'source_db_version'],
            calculate => q|
                my $citation = Genome::DruggableGene::Citation->get(source_db_name => $source_db_name, source_db_version => $source_db_version);
                return $citation;
            |,
        }
    ],
    doc => 'Claim regarding the name of a drug',
};

sub __display_name__ {
    my $self = shift;
    return $self->name . '(' . $self->source_db_name . ' ' . $self->source_db_version . ')';
}

if ($INC{"Genome/Search.pm"}) {
    __PACKAGE__->create_subscription(
        method => 'commit',
        callback => \&commit_callback,
    );
}

sub commit_callback {
    my $self = shift;
    Genome::Search->add(Genome::DruggableGene::GeneNameReport->define_set(name => $self->name));
}

sub source_id {
    my $self = shift;
    my $source_id = $self->name;
    if($source_id =~ m/^ENTRZ_G/){
        $source_id =~ s/ENTRZ_G//;
    }elsif($source_id =~ m/DGBNK_G/){
        $source_id =~ s/DGBNK_G//;
    }

    return $source_id;
}

sub convert_to_entrez {
    my $class = shift;
    my @gene_identifiers = @_;
    my ($entrez_gene_name_reports, $intermediate_gene_name_reports) = $class->_convert_to_entrez_gene_name_reports(@gene_identifiers);
    return ($entrez_gene_name_reports, $intermediate_gene_name_reports);
}

sub _convert_to_entrez_gene_name_reports {
    my $class = shift;
    my @gene_identifiers = shift;
    my ($entrez_gene_symbol_matches, $entrez_id_matches, $ensembl_id_matches, $uniprot_id_matches);
    my $intermediate_gene_name_reports;

    @gene_identifiers = $class->_strip_version_numbers(@gene_identifiers);

    ($entrez_gene_symbol_matches, @gene_identifiers) = $class->_match_as_entrez_gene_symbol(@gene_identifiers);

    if(@gene_identifiers){
        ($entrez_id_matches, @gene_identifiers) = $class->_match_as_entrez_id(@gene_identifiers);
    }

    if(@gene_identifiers){
        ($ensembl_id_matches, @gene_identifiers) = $class->_match_as_ensembl_id(@gene_identifiers);
    }

    if(@gene_identifiers){
        ($uniprot_id_matches, $intermediate_gene_name_reports, @gene_identifiers) = $class->_match_as_uniprot_id(@gene_identifiers);
    }

    my $merged_conversion_results = $class->_merge_conversion_results($entrez_gene_symbol_matches, $entrez_id_matches, $ensembl_id_matches, $uniprot_id_matches);

    return $merged_conversion_results, $intermediate_gene_name_reports;
}

sub _match_as_entrez_gene_symbol {
    my $class = shift;
    my @gene_identifiers = @_;
    my %matched_identifiers;
    my @unmatched_identifiers;

    my @entrez_gene_name_report_associations = Genome::DruggableGene::GeneNameReportAssociation->get(nomenclature => ['entrez_gene_symbol', 'entrez_gene_synonym'], alternate_name => \@gene_identifiers);
    return {}, @gene_identifiers unless @entrez_gene_name_report_associations;
    for my $gene_identifier(@gene_identifiers){
        my @associations_for_identifier = grep($_->alternate_name eq $gene_identifier, @entrez_gene_name_report_associations);
        if(@associations_for_identifier){
            my @gene_name_reports_for_identifier = map($_->gene_name_report, @associations_for_identifier);
            @gene_name_reports_for_identifier = uniq @gene_name_reports_for_identifier;
            $matched_identifiers{$gene_identifier} = \@gene_name_reports_for_identifier;
        }else{
            push @unmatched_identifiers, $gene_identifier;
        }
    }

    return \%matched_identifiers, @unmatched_identifiers;
}

sub _match_as_entrez_id {
    my $class = shift;
    my @gene_identifiers = @_;
    my %matched_identifiers;
    my @unmatched_identifiers;

    my @entrez_gene_name_reports = Genome::DruggableGene::GeneNameReport->get(nomenclature => 'entrez_id', name => \@gene_identifiers);
    return {}, @gene_identifiers unless @entrez_gene_name_reports;
    for my $gene_identifier (@gene_identifiers){
        my @reports_for_identifier = grep($_->name eq $gene_identifier, @entrez_gene_name_reports);
        if(@reports_for_identifier){
            $matched_identifiers{$gene_identifier} = \@reports_for_identifier;

        }else{
            push @unmatched_identifiers, $gene_identifier;
        }
    }

    return \%matched_identifiers, @unmatched_identifiers;
}

sub _match_as_ensembl_id {
    my $class = shift;
    my @gene_identifiers = @_;
    my %matched_identifiers;
    my @unmatched_identifiers;

    my @gene_name_reports = Genome::DruggableGene::GeneNameReport->get(source_db_name => 'Ensembl', name => \@gene_identifiers);
    for my $gene_identifier(@gene_identifiers){
        my @reports_for_identifier = grep($_->name eq $gene_identifier, @gene_name_reports);
        unless(@reports_for_identifier){
            push @unmatched_identifiers, $gene_identifier;
            next;
        }
        my @temporary_identifiers = (map($_->name, @reports_for_identifier), map($_->alternate_name, map($_->gene_name_report_associations, @reports_for_identifier)));
        my ($matched_temporary_identifiers) = $class->_match_as_entrez_gene_symbol(@temporary_identifiers);
        my @complete_reports_for_identifier = map(@{$matched_temporary_identifiers->{$_}}, keys %$matched_temporary_identifiers);
        if(@complete_reports_for_identifier){
            my @complete_reports_for_identifier = uniq @complete_reports_for_identifier;
            $matched_identifiers{$gene_identifier} = \@complete_reports_for_identifier;
        }else{
            push @unmatched_identifiers, $gene_identifier;
        }
    }
    return \%matched_identifiers, @unmatched_identifiers;
}

sub _match_as_uniprot_id {
    my $class = shift;
    my @gene_identifiers = @_;
    my %matched_identifiers;
    my %intermediate_results_for_identifiers;
    my @unmatched_identifiers;

    my @uniprot_associations = Genome::DruggableGene::GeneNameReportAssociation->get(nomenclature => 'uniprot_id', alternate_name => @gene_identifiers);
    for my $gene_identifier(@gene_identifiers){
        my @associations_for_identifier = grep($_->alternate_name => @uniprot_associations);
        unless(@associations_for_identifier){
            push @unmatched_identifiers, $gene_identifier;
            next;
        }
        my @uniprot_reports_for_identifier = map($_->gene_name_report, @associations_for_identifier);
        @uniprot_reports_for_identifier = uniq @uniprot_reports_for_identifier;
        $intermediate_results_for_identifiers{$gene_identifier} = \@uniprot_reports_for_identifier;
        my @temporary_identifiers = ( map($_->name, @uniprot_reports_for_identifier), map($_->alternate_name, grep($_->nomenclature ne 'uniprot_id', map($_->gene_name_report_associations, @uniprot_reports_for_identifier))) );
        my ($matched_temporary_identifiers) = $class->_match_as_entrez_gene_symbol(@temporary_identifiers);
        my @complete_reports_for_identifier = map(@{$matched_temporary_identifiers->{$_}}, keys %$matched_temporary_identifiers);
        @complete_reports_for_identifier = uniq @complete_reports_for_identifier;
        $matched_identifiers{$gene_identifier} = \@complete_reports_for_identifier;
    }

    return \%matched_identifiers, \%intermediate_results_for_identifiers, @unmatched_identifiers;
}

sub _strip_version_numbers{
    my $class = shift;
    my @gene_identifiers = @_;
    my @updated_gene_identifiers;
    #If the incoming gene identifier has a trailing version number, strip it off before comparison
    for my $gene_identifier (@gene_identifiers){
        if ($gene_identifier =~ /(.*)\.\d+$/){
            $gene_identifier = $1;
        }
        push @updated_gene_identifiers, $gene_identifier;
    }
    return @updated_gene_identifiers;
}

sub _merge_conversion_results{
    my $class = shift;
    my @conversion_results = @_;
    my %merged = ();
    for my $conversion_result (@conversion_results){
        %merged = (%merged, %$conversion_result) if $conversion_result;
    }
    return \%merged;
}

1;
