package Genome::ProcessingProfile::Command::Describe;

use strict;
use warnings;

use Genome;

require Term::ANSIColor;
      
class Genome::ProcessingProfile::Command::Describe {
    is => 'Genome::Command::Base',
    has => [
        processing_profiles => {
            is => 'Genome::ProcessingProfile',
            is_many => 1,
            shell_args_position => 1,
            doc => 'Processing profile to list properties and params.',
        },
    ],
};

sub execute {
    my $self = shift;

    for my $pp ( $self->processing_profiles ) {
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

        print "\n";
    }

    return 1;
}

1;

