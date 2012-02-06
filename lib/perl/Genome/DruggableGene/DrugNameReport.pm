package Genome::DruggableGene::DrugNameReport;

use strict;
use warnings;

use Genome;

class Genome::DruggableGene::DrugNameReport {
    is => 'UR::Object',
    id_generator => '-uuid',
    table_name => 'dgidb.drug_name_report',
    schema_name => 'dgidb',
    data_source => 'Genome::DataSource::Main',
    id_by => [
        id => { is => 'Text'},
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
        drug_alt_names => {
            is => 'Genome::DruggableGene::DrugNameReportAssociation',
            reverse_as => 'drug_name_report',
            is_many => 1,
        },
        drug_categories => {
            is => 'Genome::DruggableGene::DrugNameReportCategoryAssociation',
            reverse_as => 'drug_name_report',
            is_many => 1,
        },
        interactions => {
            is => 'Genome::DruggableGene::DrugGeneInteractionReport',
            reverse_as => 'drug_name_report',
            is_many => 1,
        },
        gene_name_reports => {
            is => 'Genome::DruggableGene::GeneNameReport',
            via => 'interactions',
            to => 'gene_name_report',
            is_many => 1,
        },
        citation => {
            calculate_from => ['source_db_name', 'source_db_version'],
            calculate => q|
                my $citation = Genome::DruggableGene::Citation->get(source_db_name => $source_db_name, source_db_version => $source_db_version);
                return $citation;
            |,
        },
        is_withdrawn => {
            calculate => q{
                return 1 if grep($_->category_value eq 'withdrawn', $self->drug_name_report_category_associations);
                return 0;
            },
        },
        is_nutraceutical => {
            calculate => q{
                return 1 if grep($_->category_value eq 'nutraceutical', $self->drug_name_report_category_associations);
                return 0;
            },
        },
        is_approved => {
            calculate => q{
                return 1 if grep($_->category_value eq 'approved', $self->drug_name_report_category_associations);
                return 0;
            },
        },
        is_antineoplastic => {
            calculate => q{
                return 1 if grep($_->category_value =~ /antineoplastic/, $self->drug_name_report_category_associations);
                return 0;
            },
        },
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
        callback => \&add_to_search_index_queue,
    );
    __PACKAGE__->create_subscription(
        method => 'delete',
        callback => \&add_to_search_index_queue,
    );
}

sub add_to_search_index_queue {
    my $self = shift;
    my $set = Genome::DruggableGene::DrugNameReport->define_set(name => $self->name);
    Genome::Search::Queue->create(
        subject_id => $set->id,
        subject_class => $set->class,
        priority => 9,
    );
}

sub source_id {
    my $self = shift;
    my $source_id = $self->name;
    return $source_id;
}

sub original_data_source_url {
    my $self = shift;
    my $base_url = $self->citation->base_url;
    my $source_id = $self->source_id;
    my $url;
    if($self->source_db_name eq 'DrugBank'){
        $url = join('/', $base_url, 'drugs', $source_id);
    }elsif($self->source_db_name eq 'TTD'){
        $url = $base_url . 'DRUG.asp?ID=' . $source_id;
    }else{
        $url = join('', $base_url, $source_id);
    }

    return $url;
}

1;
