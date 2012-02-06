package Genome::DruggableGene::GeneNameGroup;

use strict;
use warnings;

use Genome;

class Genome::DruggableGene::GeneNameGroup {
    is => 'UR::Object',
    table_name => 'dgidb.gene_name_group',
    schema_name => 'dgidb',
    data_source => 'Genome::DataSource::Main',

    id_generator => '-uuid',
    id_by => [
        id => {is => 'Text'},
    ],
    has => [
        name => { is => 'Text' },
        gene_name_group_bridges => {
            is => 'Genome::DruggableGene::GeneNameGroupBridge',
            reverse_as => 'gene_name_group',
            is_many => 1,
        },
        gene_name_reports  => {
            is => 'Genome::DruggableGene::GeneNameReport',
            via => 'gene_name_group_bridges',
            to => 'gene_name_report',
            is_many => 1,
        },
    ],
    doc => 'Group of likely synonymous genes',
};

sub consume {
    my $self = shift;
    my @groups = @_;
    for my $group (@groups){
        for my $bridge($group->gene_name_group_bridges){
             $self->add_gene_name_group_bridge(gene_name_report_id => $bridge->gene_name_report_id);
        }
        $group->delete;
    }
}

sub delete {
    my $self = shift;
    for($self->gene_name_group_bridges) {
        $_->delete;
    }
    return $self->SUPER::delete();
}
