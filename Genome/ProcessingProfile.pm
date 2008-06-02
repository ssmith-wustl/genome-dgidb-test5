package Genome::ProcessingProfile;

use strict;
use warnings;

use above "Genome";
class Genome::ProcessingProfile {
    type_name => 'processing profile',
    table_name => 'PROCESSING_PROFILE',
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

1;
