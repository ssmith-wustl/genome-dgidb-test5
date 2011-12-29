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
        drug_name_report_associations => {
            is => 'Genome::DruggableGene::DrugNameReportAssociation',
            reverse_as => 'drug_name_report',
            is_many => 1,
        },
        drug_name_report_category_associations => {
            is => 'Genome::DruggableGene::DrugNameReportCategoryAssociation',
            reverse_as => 'drug_name_report',
            is_many => 1,
        },
        drug_gene_interaction_reports => {
            is => 'Genome::DruggableGene::DrugGeneInteractionReport',
            reverse_as => 'drug_name_report',
            is_many => 1,
        },
        gene_name_reports => {
            is => 'Genome::DruggableGene::GeneNameReport',
            via => 'drug_gene_interaction_reports',
            to => 'gene_name_report',
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
    Genome::Search->add(Genome::DruggableGene::DrugNameReport->define_set(name => $self->name));
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
    }else{
        $url = join('', $base_url, $source_id);
    }

    return $url;
}

1;
