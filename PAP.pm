package PAP;

use warnings;
use strict;

use UR;
use UR::ObjectV001removed;
use Workflow;

use lib '/gscmnt/temp212/info/annotatin/bioperl-cvs/bioperl-live';
use lib '/gscmnt/temp212/info/annotatin/bioperl-cvs/bioperl-run';

class PAP {
    is => ['UR::Namespace'],
    type_name => 'pap',
};

1;
