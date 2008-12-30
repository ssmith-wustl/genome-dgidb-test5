package Genome::Model::Command::Build::AmpliconAssembly::PostProcess;

use strict;
use warnings;

use Genome;
      
class Genome::Model::Command::Build::AmpliconAssembly::PostProcess {
    is => 'Genome::Model::Event',
};

#< Subclassing...by purpose >#
sub command_subclassing_model_property {
    return 'purpose';
}

#< LSF >#
sub bsub_rusage {
    return "";
}

1;

#$HeadURL$
#$Id$
