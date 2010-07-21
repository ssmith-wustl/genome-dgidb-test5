#!/gsc/bin/perl

use strict;
use above 'MGAP';
use Workflow::Server;

my $server = Workflow::Server->create(
    namespace => 'MGAP'
);

POE::Kernel->run();


