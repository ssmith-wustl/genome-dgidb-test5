package Genome::Command::Update;

use strict;
use warnings;

use Genome;
      
require Carp;
use Data::Dumper 'Dumper';
require Scalar::Util;

class Genome::Command::Update {
    is => 'Genome::Command::Base',
    is_abstract => 1,
    attributes_have => [ is_add_remove => { is => 'Boolean', is_optional => 1, } ],
    doc => 'CRUD update command class.',
};

sub _name_for_objects { Carp::confess('Please use CRUD or implement _name_for_objects in '.$_[0]->class); }
sub _name_for_objects_ub { Carp::confess('Please use CRUD or implement _name_for_objects_ub in '.$_[0]->class); }
sub _only_if_null { Carp::confess('Please use CRUD or implement _only_if_null in '.$_[0]->class); }

sub sub_command_sort_position { .3 };

sub help_brief {
    return 'update '.$_[0]->_name_for_objects;
}

sub help_detail {
    my $class = shift;
    my $name_for_objects = $class->_name_for_objects;
    my $help = "This command updates $name_for_objects resolved via a command line string. Many $name_for_objects can be indicated at one time, as well as many properties to update.\n\n";
    if ( @{$class->_only_if_null} ) {
        $help .= 'These properties can only be updated if NULL: '.join(', ', @{$class->_only_if_null}).'.';
    }
    return $help;
}

sub execute {
    my $self = shift;

    $self->status_message('Update objects: '.$self->_name_for_objects);

    my $class = $self->class;
    my $name_for_objects_ub = $self->_name_for_objects_ub;
    my $only_if_null = $self->_only_if_null;
    my @objects = $self->$name_for_objects_ub;
    my @errors;
    my $properties_requested_to_update = 0;
    my $success = 0;

    PROPERTY: for my $property_meta ( $self->__meta__->property_metas ) {
        next PROPERTY if $property_meta->class_name ne $class;
        my $property_name = $property_meta->property_name;
        next PROPERTY if $property_name eq $name_for_objects_ub;
        my $new_value = $self->$property_name;
        next PROPERTY if not defined $new_value;
        $self->status_message("Update property: $property_name");
        $properties_requested_to_update++;
        OBJECT: for my $obj ( @objects ) {
            if ( grep { $property_name eq $_ } @$only_if_null 
                    and not $property_meta->is_add_remove
                    and defined( my $value = $obj->$property_name) ) {
                my $obj_name = $self->_get_display_name($obj);
                my $value_name = $self->_get_display_name($value);
                $self->error_message("Cannot update $obj_name '$property_name' because it already has a value: $value_name");
                next OBJECT;
            }
            my $rv = eval{ $obj->$property_name( $self->$property_name ); };
            if ( defined $rv ) { $success++; } else { $self->error_message() }
        }
    }

    my $attempted = @objects * $properties_requested_to_update;
    $self->status_message(
        sprintf(
            "Update complete.\nAttempted: %s\nFailed: %s\nSuccess: %s\n",
            $attempted,
            $attempted - $success,
            $success,
        )
    );

    return ( $success ? 1 : 0 ); 
}

sub _get_display_name {
    my ($self, $value) = @_;

    if ( Scalar::Util::blessed($value) ) {
        my $display_name =  $value->can('__display_name__');
        return $display_name->($value) if $display_name;
        return $value->id;
    }

    return $value;
}

1;

