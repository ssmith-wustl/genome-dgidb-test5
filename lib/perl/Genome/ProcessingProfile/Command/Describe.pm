package Genome::ProcessingProfile::Command::Describe;

#REVIEW fdu 11/20/1009
#1. Remove 'use Command' and 'use Data::Dumper';
#2. Remove 'sub _print_processing_profiles_values_for_property'

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

    $self->_verify_processing_profile
        or return;
    
    my $pp = $self->processing_profile;

    # Base processing profile attrs
    printf(
        "%s %s <ID: %s>\ntype_name: %s\n", 
        Term::ANSIColor::colored('Processing Profile:', 'bold'),
        Term::ANSIColor::colored($pp->name, 'red'),
        Term::ANSIColor::colored($pp->id, 'red'),
        Term::ANSIColor::colored($pp->type_name, 'red'),
    );

    # Params
    for my $param ( sort { $a cmp $b } $pp->params_for_class ) {
        my $value = $pp->$param;
        printf(
            "%s: %s\n",
            $param,
            Term::ANSIColor::colored(( defined $value ? $value : '<NULL>'), 'red'),
        );
    }

    return 1;
}

sub _print_processing_profiles_values_for_property {
    my ($self, $name, $value) = @_;

    return 1;
}

1;

#$HeadURL$
#$Id$
