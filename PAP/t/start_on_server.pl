#!/gsc/bin/perl

use strict;
use warnings;

use lib '/gscuser/mjohnson/bioperl-svn/bioperl-live/';
use lib '/gscuser/mjohnson/bioperl-svn/bioperl-run/';

use above 'Workflow';

use Workflow::Client;
use POE;

Workflow::Client->execute_workflow(
    xml_file => 'data/pap_outer_keggless.xml',
    input => {
              'fasta file'       => 'data/B_coprocola.fasta',
              'chunk size'       => 10,
              'biosql namespace' => 'MGAP',
              'gram stain'       => 'negative',
    },
    no_run => 1
);

POE::Kernel->run();
