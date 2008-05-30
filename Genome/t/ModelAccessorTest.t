#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";

use Test::More 'no_plan';

my @genome_models = Genome::Model->get();

for my $model (@genome_models) {
	# Get the subclass type
	my $subclass_path = $model->processing_profile->resolve_subclass_name();
	ok($subclass_path, "subclass resolved");
	print $subclass_path ."\n";
	
	# Get the matching processing profile of the subclass type and check there is only one
	my @processing_profiles = $subclass_path->get(id => $model->processing_profile_id);
	is(scalar(@processing_profiles), 1, "Exactly one profile matches");
	my $processing_profile = $processing_profiles[0];
	
	# Compare all attributes of subclass and genome model accessors
	for my $property ($processing_profile->get_class_object->all_property_names)
	{	
		# compare all properties that the model shares with the processing profile
		if ($model->can($property)) {
			# cannot compare names because they are not necessarily similar
			unless ($property eq 'name') {
				is($model->$property, $processing_profile->$property , "The value for $property in genome_model matches the value in processing_profile");
			}	
		}	
	}
}


