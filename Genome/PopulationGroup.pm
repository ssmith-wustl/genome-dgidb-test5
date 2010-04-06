package Genome::PopulationGroup;

# Adaptor for GSC::PopulationGroup

# Do NOT use this module from anything in the GSC schema,
# though the converse will work just fine.

# This module should contain only UR class definitions,
# relationships, and support methods.

use strict;
use warnings;

use Genome;

class Genome::PopulationGroup {
    is => 'Genome::SampleSource',
    table_name => 'GSC.POPULATION_GROUP@dw population_group',
    id_by => [
        individual_id => { is => 'Number', len => 10, column_name => 'PG_ID' },
    ],
    has_many => [
        member_links        => { is => 'Genome::PopulationGroup::Member', reverse_id_by => 'population_group' },
        members             => { is => 'Genome::Individual', via => 'member_links', to => 'member' },
    ],
    doc => 'an defined, possibly arbitrary, group of individual organisms',
    data_source => 'Genome::DataSource::GMSchema',
};

sub create {
    my $class = shift;
    my $bx = $class->define_boolexpr(@_);
    
    my $delegate = GSC::PopulationGroup->create(taxon_id => 1653198763, $bx->params_list);
    unless ($delegate) {
        $class->error_message(GSC::PopulationGroup->error_message || 'unlogged create() error!');
        return;
    }

    my $measurable;
    $measurable = GSC::Phenotype::Measurable->get(
        subject_id => $delegate->id, 
    );
    unless ($measurable) { 
        $measurable = GSC::Phenotype::Measurable->create(
            subject_id => $delegate->id, 
            subject_type => $delegate->get_class_object->type_name
        );
        unless ($measurable) {
            $delegate->delete;
            die "failed to create a GSC::Phenotype::Measurable entity for $class!";
        }
    } 
    
    my $self = $class->__define__(id => $delegate->id, $bx->params_list);
    unless ($self) {
        die "Failed to fabricate new $class " . $delegate->id;
    }

    return $self;
}

1;

