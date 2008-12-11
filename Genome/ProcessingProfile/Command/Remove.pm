package Genome::ProcessingProfile::Command::Remove;

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

    # These are for convenience, and the ability to output the name and id upon successful removal
    my $pp = $self->processing_profile;
    my $pp_name = $pp->name;
    my $pp_id = $pp->id;

    if ( Genome::Model->get(processing_profile_name => $pp_name) ) {
        $self->error_message(
            sprintf(
                'Processing profile (%s <ID: %s>) has existing models.  Remove the models first, then remove the processing profile',
                $pp_name,
                $pp_id,
            )
        );
        return;
    }
    
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
