package Genome::Individual;

use strict;
use warnings;

use Genome;

use Carp;

class Genome::Individual {
    is => 'Genome::Subject',
    has => [
        individual_id => {
            calculate_from => 'id',
            calculate => q{ return $id; },
        },
        taxon_id => {
            is => 'Number',
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'taxon_id' ],
            is_mutable => 1,
        },
        taxon => { 
            is => 'Genome::Taxon', 
            id_by => 'taxon_id', 
        },
        species_name => { 
            via => 'taxon' 
        },
        subject_type => { 
            is => 'Text', 
            is_constant => 1, 
            value => 'organism individual'
        },
    ],
    has_optional => [
        father_id => {
            is => 'Number',
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'father_id' ],
            is_mutable => 1,
        },
        father => { 
            is => 'Genome::Individual', 
            id_by => 'father_id' 
        },
        father_name => { 
            via => 'father', 
            to => 'name' 
        },
        mother_id => {
            is => 'Number',
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'mother_id' ],
            is_mutable => 1,
        },
        mother => { 
            is => 'Genome::Individual', 
            id_by => 'mother_id' 
        },
        mother_name => { 
            via => 'mother', 
            to => 'name' 
        },
        upn => { 
            is => 'Text', 
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'upn' ],
            is_mutable => 1,
            doc => 'fully qualified internal name for the patient', 
        },
        common_name => { 
            is => 'Text',
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'common_name' ],
            is_mutable => 1,
            doc => 'a name like "aml1" for the patient, by which the patient is commonly referred-to in the lab' 
        },
        gender => { 
            is => 'Text',
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'gender' ],
            is_mutable => 1,
            doc => 'when the gender of the individual is known, this value is set to male/female/...' 
        },
        ethnicity => { 
            is => 'Text',
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'ethnicity' ],
            is_mutable => 1,
            doc => 'the "ethnicity" of the individual, Hispanic/Non-Hispanic/...'
        },
        race => { 
            is => 'Text',
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'race' ],
            is_mutable => 1,
            doc => 'the "race" of the individual, African American/Caucasian/...'
        },
    ],
    has_many_optional => [
        samples => { 
            is => 'Genome::Sample', 
            reverse_id_by => 'source',
        },
        sample_names => {
            is => 'Text',
            via => 'samples',
            to => 'name',
        },
    ],
};

sub __display_name__ {
    my $self = shift;
    if (defined $self->name) {
        return $self->name .' (' . $self->id . ')';
    }
    else {
        return '(' . $self->id . ')';
    }
}

1;

