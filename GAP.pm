package GAP;

use warnings;
use strict;

use UR;
use UR::ObjectV001removed;
use Workflow;

#use lib '/gscmnt/temp212/info/annotation/bioperl-svn/bioperl-live';
#use lib '/gscmnt/temp212/info/annotation/bioperl-svn/bioperl-run';
use lib '/gsc/scripts/opt/bacterial-bioperl';

class PAP {
    is => ['UR::Namespace'],
    type_name => 'gap',
};

1;
