#!/gsc/bin/perl

use strict;
use warnings;

use lib '/gscuser/mjohnson/bioperl-svn/bioperl-live/';
use lib '/gscuser/mjohnson/bioperl-svn/bioperl-run/';

use above 'Workflow';

use Workflow::Client;
use POE;

Workflow::Client->resume_workflow(
    instance_id => 337,
    no_run => 1
);

POE::Kernel->run();
