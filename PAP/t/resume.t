#!/gsc/bin/perl

use strict;
use warnings;

#use lib '/gscuser/mjohnson/bioperl-svn/bioperl-live';
#use lib '/gscuser/mjohnson/bioperl-svn/bioperl-run';

use above 'Workflow';
use Data::Dumper;
use PAP;

my $i = Workflow::Store::Db::Operation::Instance->get(88);
$i->operation->set_all_executor(Workflow::Executor::SerialDeferred->create());

#$i->status('crashed');
#$i->is_done(0);

#my $mainpeer = Workflow::Store::Db::Operation::Instance->get(92);
#for my $p ($mainpeer, $mainpeer->peers) {
#    $p->is_done(0);
#    $p->status('new');
#    $p->output_connector->status('new');
#    $p->output_connector->is_done(0);
#}

#my $dbupload = Workflow::Store::Db::Operation::Instance->get(101);
#$dbupload->status('crashed');
#$dbupload->is_done(0);

#for my $id (90,99,89,100,91) {
#    my $obj = Workflow::Store::Db::Operation::Instance->get($id);

#    $obj->status('new');
#    $obj->is_done(0);
#}

#my $outcat = Workflow::Store::Db::Operation::Instance->get(90);
#my $mainpeer = Workflow::Store::Db::Operation::Instance->get(92);
#foreach my $p ($mainpeer, $mainpeer->peers) {
#    $outcat->input()->{'blastp psortb feature'}->[$p->parallel_index] =
#    Workflow::Link::Instance->create(
#        operation_instance => $p,
#        property => 'bio seq features'
#    );
#}

$i->resume();
$i->operation->wait;

1;
