package Genome::Model::Report::Table;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';

class Genome::Model::Report::Table {
    is => 'Genome::Report::Generator',
    has => [
        name => {
            is => 'Text',
            doc => 'Name of report.',
        },
        description => {
            is => 'Text',
            doc => 'Report description.',
        },
        properties => {
            is => 'ARRAY',
            doc => 'Objects to display in the table.',
        },
        rows => {
            is => 'ARRAY',
            doc => 'Rows of data to display.',
        },
    ],
};

sub create { 
    my $class = shift;

    my $self = $class->SUPER::create(@_)
        or return;

    for my $property_name (qw/ name description /) {
        unless ( defined $self->$property_name ) {
            $self->error_message("Property ($property_name) is required.");
            return;
        }
    }

    for my $property_name (qw/ properties rows /) {
        my $value = $self->$property_name;
        unless ( $value ) {
            $self->error_message("Property ($property_name) is required.");
            return;
        }
        my $ref = ref($value);
        unless ( $ref and $ref eq 'ARRAY' ) {
            $self->error_message("Property ($property_name) is required to be an array reference.");
            return;
        }
    }

    return $self;
}

sub _add_to_report_xml {
    my $self = shift;

    $self->_add_dataset(
        name => 'headers',
        row_name => 'header',
        headers => [qw/ value /],
        rows => [
        map { [ 
            Genome::Utility::Text::capitalize_words($_)
            ] } map { 
            local $_ = $_; # so we don't stomp on the dashed headers
            s/\-/ /g; $_ 
        } @{$self->properties} 
        ], 
    );

    $self->_add_dataset(
        name => 'objects',
        row_name => 'object',
        headers => $self->properties,
        rows => $self->rows,
    );

    return 1;
}

1;

#$HeadURL$
#$Id$
