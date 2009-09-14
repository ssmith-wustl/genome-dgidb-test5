package Genome::Model::ViromeScreen;

use strict;
use warnings;

use Genome;

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

sub build_subclass_name {
    return 'virome-screen';
}

1;
