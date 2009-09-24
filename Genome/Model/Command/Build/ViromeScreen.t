#!/gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Genome::Model::Command::Build::ViromeScreen::Test;

Genome::Model::Command::Build::ViromeScreen::Test->runtests;

exit;

