package Genome::Model::Command::Build::DeNovoAssembly::Preprocess::Velvet;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';

class Genome::Model::Command::Build::DeNovoAssembly::Preprocess::Velvet {
    is => 'Genome::Model::Command::Build::DeNovoAssembly::Preprocess',
};

sub valid_params {
    my %params = (
	);
    return \%params;
}

1;

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/trunk/Genome/Model/Command/Build/DeNovoAssembly/PrepareInstrumentData.pm $
#$Id: PrepareInstrumentData.pm 45247 2009-03-31 18:33:23Z ebelter $
