package MGAP;

use warnings;
use strict;

use UR;
use Workflow;

use lib '/gscmnt/temp212/info/annotation/bioperl-svn/bioperl-live';
use lib '/gscmnt/temp212/info/annotation/bioperl-svn/bioperl-run';

class MGAP {
    is => ['UR::Namespace'],
    type_name => 'mgap',
};

1;
