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
