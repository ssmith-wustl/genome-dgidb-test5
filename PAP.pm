package PAP;

use warnings;
use strict;

use UR;
use Workflow;

use lib '/gscuser/mjohnson/bioperl-svn/bioperl-live';
use lib '/gscuser/mjohnson/bioperl-svn/bioperl-run';

class PAP {
    is => ['UR::Namespace'],
    type_name => 'pap',
};

1;
