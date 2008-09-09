package Genome::ProcessingProfile::Sanger;

use strict;
use warnings;

use Genome;

class Genome::ProcessingProfile::Sanger {
    is => 'Genome::ProcessingProfile',
    has => [
        process_param_set_id => {
            via         => 'params',
            to          => 'value',
            where       => [name => 'process_param_set_id'],
            is_mutable  => 1,
        },
    ],
};

sub params_for_class{
    my $self = shift;
    return qw/process_param_set_id/;
}

1;

=cut
=cut

