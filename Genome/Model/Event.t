
use strict;
use warnings;
use Genome;

use Test::More tests => 5;


use_ok("Genome::Model::Event");

diag("testing sub-classification by event_type formula...");

my $event_type = "genome-model add-reads assign-run solexa";
my $event_class_name = "Genome::Model::Command::AddReads::AssignRun::Solexa";

my $e1 = Genome::Model::Event->create(event_type => $event_type, id => -1);
ok($e1, "created an object");

isa_ok($e1,$event_class_name);

my @ds = UR::Context->get_current->resolve_data_sources_for_class_meta_and_rule(
    UR::Object::Type->get("Genome::Model::Event"),
    UR::BoolExpr->resolve_for_class_and_params("Genome::Model::Event", ())
);
my $e2_id = $ds[0]->get_default_dbh->selectrow_array("select min(genome_model_event_id) from genome_model_event where event_type = '$event_type'");
ok($e2_id, "got an id from the database directly: $e2_id");

my $e2 = Genome::Model::Event->get($e2_id);
is(ref($e2),$event_class_name, "new object is sub-classified correctly");



