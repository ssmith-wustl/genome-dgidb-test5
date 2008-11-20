package Genome::ProcessingProfile::Command::Describe;

use strict;
use warnings;

use Genome;

use Command; 
use Data::Dumper;
require Term::ANSIColor;
      
class Genome::ProcessingProfile::Command::Describe {
    is => 'Genome::ProcessingProfile::Command',
};

sub execute {
    my $self = shift;

    printf(
        "%s %s <ID: %s>\n", 
        Term::ANSIColor::colored('Processing Profile:', 'bold'),
        Term::ANSIColor::colored($self->processing_profile->name, 'red'),
        Term::ANSIColor::colored($self->processing_profile->id, 'red'),
    );

    for my $property ( sort { $a->property_name cmp $b->property_name } $self->processing_profile->get_class_object->get_property_objects ) {
        $self->_print_processing_profiles_values_for_property($property->property_name)
            or return;
    }
    
    return 1;
}

sub _print_processing_profiles_values_for_property {
    my ($self, $property_name) = @_;

    my @values = $self->processing_profile->$property_name;
    print sprintf(
        "%s %s\n",
        $property_name . ':',
        #Term::ANSIColor::colored($property_name . ':', 'bold'),
        Term::ANSIColor::colored((@values ? join(',', @values) : '<NULL>'), 'red'),
    );

    return 1;
}

1;

#$HeadURL$
#$Id$
