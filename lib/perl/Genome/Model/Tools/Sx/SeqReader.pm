package Genome::Model::Tools::Sx::SeqReader;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::Sx::SeqReader {
    is_abstract => 1,
    has => [ 
        name => { is => 'Text', is_optional => 1, },
        file => { is => 'Text', }, 
    ],
};

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_);
    return if not $self;

    for my $property ( $self->_file_properties ) {
        my $property_name = $property->property_name;
        my $file = $self->$property_name; 
        if ( not $file ) {
            next if $property->is_optional;
            $self->error_message("File ($property_name) is required");
            return;
        }
        my $fh = eval{ Genome::Sys->open_file_for_reading($file); };
        if ( not $fh ) {
            $self->error_message("Failed to open file ($file)");
            return;
        }
        $self->{'_'.$property_name} = $fh;
    }

    return $self;
}

sub _file_properties {
    my $self = shift;

    my @properties;
    for my $property ( sort { $a->property_name cmp $b->property_name } $self->__meta__->property_metas ) {
        next if $property->property_name !~ /file$/;
        push @properties, $property;
    }

    return @properties;
}

1;

