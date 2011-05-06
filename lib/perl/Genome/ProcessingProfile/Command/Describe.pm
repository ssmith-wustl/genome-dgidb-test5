package Genome::ProcessingProfile::Command::Describe;

use strict;
use warnings;

use Genome;

require Term::ANSIColor;
      
class Genome::ProcessingProfile::Command::Describe {
    is => 'Genome::Command::Base',
    has => [
        processing_profile => {
            is => 'Genome::ProcessingProfile',
            doc => 'Processing profile to list properties and params.',
        },
    ],
};

sub execute {
    my $self = shift;

    my $pp = $self->processing_profile;
    return if not $pp or not ref $pp;

    printf(
        "%s %s <ID: %s>\ntype_name: %s\n", 
        Term::ANSIColor::colored('Processing Profile:', 'bold'),
        Term::ANSIColor::colored($pp->name, 'red'),
        Term::ANSIColor::colored($pp->id, 'red'),
        Term::ANSIColor::colored($pp->type_name, 'red'),
    );

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

1;

