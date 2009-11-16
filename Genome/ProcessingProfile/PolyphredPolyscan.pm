package Genome::ProcessingProfile::PolyphredPolyscan;

#:eclark 11/16/2009 Code review.

# Seems like there should better way to define a build that only does one thing.  Implement params_for_class in the base class using introspection.

use strict;
use warnings;

use Genome;

class Genome::ProcessingProfile::PolyphredPolyscan{
    is => 'Genome::ProcessingProfile',
    has => [
        sensitivity => {
            via         => 'params',
            to          => 'value',
            where       => [name => 'sensitivity'],
            is_mutable  => 1,
        },
        research_project => {
            via         => 'params',
            to          => 'value',
            where       => [name => 'research_project'],
            is_mutable  => 1,
        },
        technology => {
            via         => 'params',
            to          => 'value',
            where       => [name => 'technology'],
            is_mutable  => 1,
        },
    ],
};

sub params_for_class{
    my $self = shift;
    return qw/sensitivity research_project technology/;
}

sub stages {
    return (qw/
            polyphred_polyscan
            verify_successful_completion
            /);
}

sub polyphred_polyscan_job_classes {
    return (qw/
            Genome::Model::Command::Build::PolyphredPolyscan::Run
        /);
}

sub polyphred_polyscan_objects {
    return 1;
}



;

=cut
=cut

