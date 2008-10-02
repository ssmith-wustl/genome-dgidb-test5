#!/gsc/bin/perl

use strict;
use warnings;

#use lib '/gscuser/mjohnson/bioperl-svn/bioperl-live';
#use lib '/gscuser/mjohnson/bioperl-svn/bioperl-run';

use above 'Workflow';
use Data::Dumper;
use PAP;

my $i = Workflow::Store::Db::Operation::Instance->get(1);
$i->operation->set_all_executor(Workflow::Executor::SerialDeferred->create());
$i->operation->executor->limit(1);

$i->resume();
$i->operation->wait;

1;
