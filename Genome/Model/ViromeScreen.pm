package Genome::Model::ViromeScreen;

use strict;
use warnings;

use Genome;
use Data::Dumper;
require Genome::ProcessingProfile::ViromeScreen;

class Genome::Model::ViromeScreen {
    is => 'Genome::Model',
    has => [
	   map({
	         $_ => {
		         via => 'processing_profile',
	         }
            } Genome::ProcessingProfile::ViromeScreen->params_for_class
	),
    ],
};


sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_);

    return $self;
}

1;
