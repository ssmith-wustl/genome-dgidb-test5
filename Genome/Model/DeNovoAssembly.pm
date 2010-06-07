package Genome::Model::DeNovoAssembly;

use strict;
use warnings;

use Genome;
use Genome::ProcessingProfile::DeNovoAssembly;

class Genome::Model::DeNovoAssembly {
    is => 'Genome::Model',
    has => [
	    map({
		$_ => {
		    via => 'processing_profile',
		}
	    } Genome::ProcessingProfile::DeNovoAssembly->params_for_class
	 ),
      ],
};

sub build_subclass_name {
    return 'de-novo-assembly';
}

1;

#$HeadURL$
#$Id$
