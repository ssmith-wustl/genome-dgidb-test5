#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Genome::Model::Command::Build::DeNovoAssembly::Test;

Genome::Model::Command::Build::DeNovoAssembly::Test->runtests;

exit;

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/trunk/Genome/Model/Command/Build/DeNovoAssembly/PrepareInstrumentData.t $
#$Id: PrepareInstrumentData.t 45247 2009-03-31 18:33:23Z ebelter $
