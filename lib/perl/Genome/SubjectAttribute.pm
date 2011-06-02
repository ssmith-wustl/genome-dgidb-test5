package Genome::SubjectAttribute;

use strict;
use warnings;
use Genome;

class Genome::SubjectAttribute {
    table_name => 'GENOME_SUBJECT_ATTRIBUTE',
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
    doc => 'Represents a particular attribute of a subject',
    id_by => [
        attribute_label => {
            is => 'Text',
        },
        subject_id => {
            is => 'Text',
        },
        attribute_value => {
            is => 'Text',
        },
        nomenclature => {
            is => 'Text',
        },
    ],
    has => [        
        subject => {
            is => 'Genome::Subject',
            id_by => 'subject_id',
        },
        _individual => {
            is => 'Genome::Individual',
            id_by => 'attribute_value',
        },
    ],
};

sub create {
    my $class = shift;
    my $bx = $class->define_boolexpr(@_);    
    # TODO This is a workaround that allows nomenclature to be in the id_by block
    # and have a default value. Doing so in the class definition doesn't work due
    # to some sort of UR bug that Tony is aware of.
    unless ($bx->specifies_value_for('nomenclature')) {
        $bx = $bx->add_filter('nomenclature' => 'WUGC');
    }
    return $class->SUPER::create($bx);
}


1;

