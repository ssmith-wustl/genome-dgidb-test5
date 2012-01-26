package Genome::Model::SimpleAlignment;

use strict;
use warnings;

use Genome;

class Genome::Model::SimpleAlignment {
    is  => 'Genome::ModelDeprecated',
    has => [
       reference_sequence_name => { via => 'processing_profile'},
    ],
    
};


# we get a failure during verify successful completion
# if we don't have this...
sub keep_n_most_recent_builds
{
    my $self = shift;
    return;
}


1
;
