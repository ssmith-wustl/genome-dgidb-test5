package Genome::Subject;

use strict;
use warnings;
use Genome;

class Genome::Subject {
    is => 'Genome::Notable',
    is_abstract => 1,
    subclassify_by => 'subclass_name',
    id_by => [
        subject_id => {
            is => 'Number',
        },
    ],
    has => [
        subclass_name => {
            is => 'Text',
        },
        subject_type => {
            column_name => '',
            is_abstract => 1,
            doc => 'Plain text description of the type of subject, defined in subclasses',
        },
    ],
    has_many_optional => [
        attributes => {
            is => 'Genome::SubjectAttribute',
            reverse_as => 'subject',
        },
    ],
    has_optional => [
        name => {
            is => 'Text',
        },
        common_name => {
            calculate_from => 'name',
            calculate => q{ return $name },
        },
        description => { 
            is => 'Text',
            via => 'attributes',
            to => 'attribute_value',
            is_mutable => 1,
            where => [ attribute_label => 'description' ],
        },
        nomenclature => {
            is => 'Text',
            via => 'attributes',
            to => 'attribute_value',
            is_mutable => 1,
            where => [ attribute_label => 'nomenclature', nomenclature => 'WUGC' ],
        },
    ],
    table_name => 'GENOME_SUBJECT',
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
    doc => 'Contains all information about a particular subject (sample, individual, taxon, etc)',
};

sub __display_name__ {
    my $self = shift;
    my $name = $self->name . ' ' if defined $self->name;
    $name .= '(' . $self->id . ')';
    return $name;
}
    
sub create {
    my ($class, %params) = @_;

    # This extra processing allows for someone to create a subject with properties that aren't listed in any of the
    # class definitions. Instead of having UR catch these extras and die, they are captured here and later turned into
    # subject attributes. Useful for clinical data that isn't expected but should nonetheless be recorded.
    my %extra;
    my @property_names = ('id', map { $_->property_name } ($class->__meta__->_legacy_properties, $class->__meta__->all_id_by_property_metas));
    for my $param (sort keys %params) {
        unless (grep { $param eq $_ } @property_names) {
            $extra{$param} = delete $params{$param};
        }
    }

    my $self = $class->SUPER::create(%params);
    unless ($self) {
        Carp::confess "Could not create subject with params: " . Data::Dumper::Dumper(\%params);
    }

    for my $label (sort keys %extra) {
        my $attribute = Genome::SubjectAttribute->create(
            attribute_label => $label,
            attribute_value => $extra{$label},
            subject_id => $self->subject_id,
        );
        unless ($attribute) {
            $self->error_message("Could not create attribute $label => " . $extra{$label} . " for subject " . $self->subect_id);
            $self->delete;
        }
    }

    return $self;
}

sub delete {
    my $self = shift;
    my @attributes = $self->attributes;
    for my $attribute (@attributes) {
        Carp::confess "Could not delete attribute " . $attribute->attribute_label . " for subject " . $self->id unless $attribute->delete;
    }
    return $self->SUPER::delete;
}

1;

