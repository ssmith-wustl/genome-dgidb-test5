#!/gsc/bin/perl

use strict;
use above 'Workflow';
use Workflow::Client;
use POE;

Workflow::Client->execute_workflow(
    xml_file => 'data/mgap.xml',
    input => {
        'dev flag' => 1,
        'seq set id' => 50 
    },
    no_run => 1
);

POE::Kernel->run();


