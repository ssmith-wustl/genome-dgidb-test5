#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';

use Test::More;

use_ok('Genome::Model::Event::Build::DeNovoAssembly');

is(Genome::Model::Event::Build::DeNovoAssembly->bsub_rusage, "-R 'span[hosts=1] select[type==LINUX64]'", 'bsub params');

done_testing();
exit;

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/trunk/Genome/Model/Command/Build/DeNovoAssembly/PrepareInstrumentData.t $
#$Id: PrepareInstrumentData.t 45247 2009-03-31 18:33:23Z ebelter $
