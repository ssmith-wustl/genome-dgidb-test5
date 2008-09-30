#!/gsc/bin/perl

use strict;
use warnings;

use lib '/gscuser/mjohnson/bioperl-svn/bioperl-live/';
use lib '/gscuser/mjohnson/bioperl-svn/bioperl-run/';

use above 'PAP';

use Workflow;
use Workflow::Server;
use Workflow::Server::HTTPD;

my $server = Workflow::Server->create(
    namespace => 'PAP'
);
my $http = Workflow::Server::HTTPD->create;

POE::Kernel->run();
