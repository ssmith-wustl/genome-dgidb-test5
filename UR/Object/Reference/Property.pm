package UR::Object::Reference::Property;

use strict;
use warnings;

=cut

UR::Object::Type->define(
    class_name => 'UR::Object::Reference::Property',
    english_name => 'type attribute has a',
    id_properties => [qw/tha_id rank/],
    properties => [
        rank                             => { type => 'NUMBER', len => 2 },
        tha_id                           => { type => 'NUMBER', len => 10 },
        attribute_name                   => { type => 'VARCHAR2', len => 64, is_optional => 1 },
        property_name                    => { type => 'VARCHAR2', len => 64, is_optional => 1 },
        r_attribute_name                 => { type => 'VARCHAR2', len => 64, is_optional => 1 },
        r_property_name                  => { type => 'VARCHAR2', len => 64, is_optional => 1 },
    ],
);

=cut

sub reference_id {
    # forward-compatible alias for the old "type has a" now "reference"
    shift->tha_id
}


# We're overriding get() so these objects can get created on the fly
sub get {
    my $class = shift;

    # Do they already exist?
    my @o = $class->SUPER::get(@_);
    return $class->context_return(@o) if (@o);

    my @refs;
    my %params;
    if (@_ == 1) {
        if ($_[0]->isa('UR::BoolExpr')) {
            @refs = UR::Object::Reference->get($_[0]);
            %params = $_[0]->params_list;
        } else {
            my($tha_id, $rank) = $class->get_class_object->resolve_ordered_values_from_composite_id($_[0]);
            @refs = UR::Object::Reference->get(tha_id => $tha_id);
            @params{'tha_id','rank'} = ($tha_id, $rank);
        } 

    } else {
        %params = @_;
        unless ($params{'tha_id'}) {
            if ($params{'class_name'} and $params{'property_name'}) {
                $params{'tha_id'} = $params{'class_name'} . '::' . $params{'property_name'};
            } else {
                Carp::confess("Required parameter (tha_id) missing");
            }
        }
        my $tha_id = $params{'tha_id'};
        @refs = UR::Object::Reference->get(id => $tha_id);
    }

    unless (@refs) {
        return;  # If there's no reference objects, there can't be any reference properties
    }

    my @defined_objects;
    foreach my $ref ( @refs ) {

        my $class_name = $ref->class_name;
        my $class_meta = UR::Object::Type->get(class_name => $class_name);
        my $delegation_property_meta = $class_meta->get_property_meta_by_name($ref->delegation_name);
        unless ($delegation_property_meta) {
            return;
        }

        my @property_names = @{$delegation_property_meta->{'id_by'}};
        my $property_names_count = scalar(@property_names);

        my $r_class_name = $ref->r_class_name;
        my $r_class_meta = UR::Object::Type->get(class_name => $r_class_name);
        my @r_property_names = $r_class_meta->id_property_names;
        my $r_property_names_count = scalar(@r_property_names);

        if ($property_names_count == 1 and $r_property_names_count > 1) {
            # Assumme this points directly to the composite 'id' property of the remote class
            @r_property_names = ('id');

        } elsif ($property_names_count != $r_property_names_count) {
            Carp::confess("Unequal property counts describing reference " . $ref->tha_id .
                          ".   Property " .  $delegation_property_meta->property_name .
                          " has $property_names_count id properties while class $r_class_name has $r_property_names_count");
        }

        my $rank = 0;
        for (my $i = 0; $i < $property_names_count; $i++) {
            my $property_name = $property_names[$i];
            my $property_meta = $class_meta->get_property_meta_by_name($property_name);
            my $attribute_name = $property_meta->attribute_name;

            my $r_property_name = $r_property_names[$i];
            my $r_property_meta = $r_class_meta->get_property_meta_by_name($r_property_name);
            my $r_attribute_name = $r_property_meta->attribute_name;

            my %get_define_params = ( 
                         tha_id           => $ref->tha_id,
                         rank             => $i+1,
                         property_name    => $property_name,
                         attribute_name   => $attribute_name,
                         r_property_name  => $r_property_name,
                         r_attribute_name => $r_attribute_name,
                     );
            my $rp = $class->SUPER::get(%get_define_params) 
                      ||
                     UR::Object::Reference::Property->define(%get_define_params);

            unless ($rp) {
                $DB::single=1;
                Carp::confess('Failed to define relationship ' . $ref->delegation_name . " property $property_name");
            }

            {
                use Data::Dumper; 
                no strict;
                my $db_committed = eval(Data::Dumper::Dumper($rp));
                $rp->{'db_committed'} ||= $db_committed;
                delete $db_committed->{'id'};
            }

            push @defined_objects, $rp;
        } # end for 0 .. $property_names_count
    } # end foreach @refs

    # We may have created more than was actually asked for
    my $rule = UR::BoolExpr->resolve_for_class_and_params($class,%params);
    $class->context_return(grep { $rule->evaluate($_) } @defined_objects);
}

sub create_object
{
    my $class = shift;
    my %params = @_;
    if ($params{attribute_name} and not $params{property_name}) {
        my $property_name = $params{attribute_name};
        $property_name =~ s/ /_/g;
        $params{property_name} = $property_name;
    }
    elsif ($params{property_name} and not $params{attribute_name}) {
        my $attribute_name = $params{property_name};
        $attribute_name =~ s/_/ /g;
        $params{attribute_name} = $attribute_name;
    }
    if ($params{r_attribute_name} and not $params{r_property_name}) {
        my $r_property_name = $params{r_attribute_name};
        $r_property_name =~ s/ /_/g;
        $params{r_property_name} = $r_property_name;
    }
    elsif ($params{r_property_name} and not $params{r_attribute_name}) {
        my $r_attribute_name = $params{r_property_name};
        $r_attribute_name =~ s/_/ /g;
        $params{r_attribute_name} = $r_attribute_name;
    }
    return $class->SUPER::create_object(%params);
}

sub _reference_class
{
    my $self = shift;
    if ($self->isa('UR::Object::Ghost')) {
        return 'UR::Object::Reference::Ghost';
    }
    else {
        return 'UR::Object::Reference';
    }
}

sub get_reference
{
    my $self = shift;
    return $self->_reference_class->get($self->tha_id);
}

sub class_name
{
    my $self = shift;
    my $r = $self->get_reference;
    return $r->class_name;
}


sub r_class_name
{
    shift->get_reference->r_class_name
}

sub get_with_special_parameters 
{
    my $class = shift;
    my $rule = shift;
    my %extra = @_;    
    if (my $class_name = delete $extra{class_name}) {
        unless (keys %extra) {
            # turn the class name into one or more ids for UR::Object::Reference.
            my @r = UR::Object::Reference->get(class_name => $class_name);
            return $class->get($rule->params_list, tha_id => \@r);
        }
    } elsif (my $r_class_name = delete $extra{r_class_name}) {
        unless (keys %extra) {
            # turn the class name into one or more ids for UR::Object::Reference.
            my @r = UR::Object::Reference->get(r_class_name => $r_class_name);
            return $class->get($rule->params_list, tha_id => \@r);
        }
    }
    return $class->SUPER::get_with_special_parameters($rule,@_);
}

1;
