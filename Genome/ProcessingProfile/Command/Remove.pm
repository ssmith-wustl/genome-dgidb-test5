package Genome::ProcessingProfile::Command::Remove;

#REVIEW fdu 11/20/2009
#1. Remove 'use Data::Dumper'
#2. Need add codes to check which models are using the
#processing-profile to be deleted and print out the list as warning

use strict;
use warnings;

use Genome;

use Data::Dumper;

class Genome::ProcessingProfile::Command::Remove {
    is => 'Genome::ProcessingProfile::Command',
};

sub execute {
    my $self = shift;

    $self->_verify_processing_profile
        or return;

    # These are for convenience, and the ability to output the name and id
    #  upon successful removal cuz there won't be a pp anymore
    my $pp = $self->processing_profile;
    my $pp_name = $pp->name;
    my $pp_id = $pp->id;

    unless ( $pp->delete ) {
        $self->error_message(
            sprintf(
                'Could not remove processing profile "%s" <ID: %s>', 
                $pp_name,
                $pp_id,
            )
        );
        return;
    }

    $self->status_message(
        sprintf(
            'Removed processing profile "%s" <ID: %s>', 
            $pp_name,
            $pp_id,
        )
    );

    return 1;
}

1;

#$HeadURL$
#$Id$
