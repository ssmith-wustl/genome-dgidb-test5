package Genome::ProcessingProfile;

use strict;
use warnings;

use above "Genome";
class Genome::ProcessingProfile {
    type_name => 'processing profile',
    table_name => 'PROCESSING_PROFILE',
    is_abstract => 1,
    first_sub_classification_method_name => '_resolve_subclass_name',
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

# resolves the full subclass name based upon the type_name field
sub resolve_subclass_name {
	my $self = shift;
	my $subclass = $self->type_name;

	my @subclass_parts = map { ucfirst } split(' ', $subclass);
	$subclass = join('', @subclass_parts);

	my $class_name = join('::', 'Genome::ProcessingProfile' , $subclass);
	return $class_name;
}

# Calls the subclass's pretty_print_text
sub pretty_print_text {
	my $self = shift;
	
	my $subclass = $self->resolve_subclass_name();
	my $subclass_instance = $subclass->get(name => $self->name);
	$subclass_instance->pretty_print_text();
}

############ event.pm stuff ####################
# This is called by the infrastructure to appropriately classify abstract events
# according to their event type because of the "sub_classification_method_name" setting
# in the class definiton...
# TODO: replace with cleaner calculated property.
sub _resolve_subclass_name {
	my $class = shift;
	
	if (ref($_[0]) and $_[0]->isa(__PACKAGE__)) {
		my $type_name = $_[0]->type_name;
		return $class->_resolve_subclass_name_for_type_name($type_name);
	}
	else {
		# What goes here? When would it fail the above case?
		# bomb bomb bomb...
		$class->error_message("Error in _resolve_subclass_name");
		return;
	}
}

# This is called by both of the above.
sub _resolve_subclass_name_for_type_name {
	$DB::single=1;
    my ($class,$type_name) = @_;
    my @type_parts = split(' ',$type_name);
	
    my @sub_parts = map { ucfirst } @type_parts;
    my $subclass = join('',@sub_parts);
	
    my $class_name = join('::', 'Genome::ProcessingProfile' , $subclass);
    return $class_name;
}

1;
