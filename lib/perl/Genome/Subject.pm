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
            is => 'Text',
        },
    ],
    has => [
        subclass_name => {
            is => 'Text',
        },
    ],
    has_many => [
        attributes => {
            is => 'Genome::SubjectAttribute',
            reverse_as => 'subject',
        },
    ],
    has_optional => [
        name => {
            is => 'Text',
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
    doc => 'Contains all information about a particular subject (library, sample, etc)',
};

sub create {
    my ($class, %params) = @_;

    # Extra parameters are turned into attributes later
    my %extra;
    my @attributes = map { $_->property_name } $class->__meta__->properties;
    for my $param (sort keys %params) {
        unless (grep { $param eq $_ } @attributes) {
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

1;

