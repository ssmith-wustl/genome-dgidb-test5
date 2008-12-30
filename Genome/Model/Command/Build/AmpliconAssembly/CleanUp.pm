package Genome::Model::Command::Build::AmpliconAssembly::CleanUp;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Build::AmpliconAssembly::CleanUp {
    is => 'Genome::Model::Event',
};

#< Subclassing...don't >#
sub _get_sub_command_class_name {
  return __PACKAGE__;
}

#< LSF >#
sub bsub_rusage {
    return "";
}

#< The Beef >#
sub execute {
    my $self = shift;

    return 1;
}

1;

#$HeadURL$
#$Id$
