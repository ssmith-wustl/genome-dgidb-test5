package Genome::ProcessingProfile;

use strict;
use warnings;

use above "Genome";

class Genome::ProcessingProfile {
    type_name => 'processing profile',
    table_name => 'PROCESSING_PROFILE',
    is_abstract => 1,
    sub_classification_method_name => '_resolve_subclass_name',
    id_by => [
        id => { is => 'NUMBER', len => 11 },
    ],
    has => [
        name      => { is => 'VARCHAR2', len => 255, is_optional => 1 },
        type_name => { is => 'VARCHAR2', len => 255, is_optional => 1 },
    ],
    has_many_optional => [
                          params => { is 'Genome::ProcessingProfile::Param', reverse_id_by => 'processing profile', },
                      ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
};

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);
    unless ($self->type_name) {
        my $type_name =
            $class->_resolve_type_name_for_subclass_name($self->class);
        $self->type_name($type_name);
    }
    return $self;
}

# Calls the subclass's pretty_print_text

sub pretty_print_text {
    my $self = shift;
    my @printable_property_names;
    unless (@printable_property_names) {
        # do this just once...
        my $class_meta = $self->get_class_object;
        for my $name ($class_meta->all_property_names) {
            next if $name eq 'name';
            my $property_meta = $class_meta->get_property_meta_by_name($name);
            unless ($property_meta->is_delegated or $property_meta->is_calculated) {
                push @printable_property_names, $name;
            }
        }
    }
    my @out;
    for my $prop (@printable_property_names) {
        if (my @values = $self->$prop) {
            my $value;
            if (@values > 1) {
                if (grep { ref($_) } @values) {
                    next;
                }
                $value = join(", ", grep { defined $_ } @values);
            }
            else {
                $value = $values[0];
            }
            next if not defined $value;
            next if ref $value;
            next if $value eq '';
            
            push @out, [
                Term::ANSIColor::colored($prop, 'red'),
                Term::ANSIColor::colored($value, "cyan")
            ]
        }
    }
    
    Genome::Model::EqualColumnWidthTableizer->new->convert_table_to_equal_column_widths_in_place( \@out );

    my $out;
    $out .= Term::ANSIColor::colored(sprintf("Processing Profile: %s (ID %s)", $self ->name, $self->id), 'bold magenta') . "\n\n";
    $out .= Term::ANSIColor::colored("Configured Properties:", 'red'). "\n";    
    $out .= join("\n", map { " @$_ " } @out);
    $out .= "\n\n";
    return $out;
}



sub Xpretty_print_text {
	my $self = shift;
	my $subclass = $self->_resolve_subclass_name();
	my $subclass_instance = $subclass->get(name => $self->name);
	$subclass_instance->pretty_print_text();
}

# This is called by the infrastructure to appropriately classify abstract processing profiles
# according to their type name because of the "sub_classification_method_name" setting
# in the class definiton...
sub _resolve_subclass_name {
	my $class = shift;
	
	if (ref($_[0]) and $_[0]->isa(__PACKAGE__)) {
		my $type_name = $_[0]->type_name;
		return $class->_resolve_subclass_name_for_type_name($type_name);
	}
    elsif (my $type_name = $class->get_rule_for_params(@_)->specified_value_for_property_name('type_name')) {
        return $class->_resolve_subclass_name_for_type_name($type_name);
    }
	else {
		return;
	}
}

# This is called by both of the above.
sub _resolve_subclass_name_for_type_name {
    my ($class,$type_name) = @_;
    my @type_parts = split(' ',$type_name);
	
    my @sub_parts = map { ucfirst } @type_parts;
    my $subclass = join('',@sub_parts);
	
    my $class_name = join('::', 'Genome::ProcessingProfile' , $subclass);
    return $class_name;
}

sub _resolve_type_name_for_subclass_name {
    my ($class,$subclass_name) = @_;
    my ($ext) = ($subclass_name =~ /Genome::ProcessingProfile::(.*)/);
    return unless ($ext);
    my @words = $ext =~ /[a-z]+|[A-Z](?:[A-Z]+|[a-z]*)(?=$|[A-Z])/g;
    my $type_name = lc(join(" ", @words));
    return $type_name;
}

1;
