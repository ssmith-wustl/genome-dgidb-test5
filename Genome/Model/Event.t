
use strict;
use warnings;
use Genome;

use Test::More;
plan tests => 12;

diag("testing sub-classification by event_type formula...");

my $event_type = "genome-model add-reads align-reads maq";
my $event_class_name = "Genome::Model::Command::AddReads::AlignReads::Maq";
my $m = Genome::Model->create(id => -1, sample_name => "test_case_sample$$",  read_aligner_name => 'maq0_6_5');
my $r = Genome::RunChunk->create(-1, sequencing_platform => 'solexa');
my $e1 = Genome::Model::Event->create(event_type => $event_type, id => -2, model_id => $m->id, run_id => $r->id);
ok($e1, "created an object");
isa_ok($e1,$event_class_name);

my $e5 = Genome::Model::Command::AddReads::AlignReads->create(
    event_type => $event_type, 
    id => -3, 
    model_id => $m->id, 
    run_id => $r->id
);
ok($e5, "created an object");
isa_ok($e5,$event_class_name);

my $e6 = Genome::Model::Command::AddReads::AlignReads->create(
    id => -4, 
    model_id => $m->id, 
    run_id => $r->id
);
ok($e6, "created an object");
isa_ok($e6,$event_class_name);

my $e3 = Genome::Model::Event->get(88243964);
ok($e3, "got an event by id");
ok($e3->isa("Genome::Model::Command::AddReads::AlignReads::Maq"), "class " . ref($e3) . " is expected align-reads/maq");

my $e4 = Genome::Model::Event->get(88243961);
ok($e4, "got another event by id: $e4");
ok($e4->isa("Genome::Model::Command::AddReads::AssignRun::Solexa"), "class " . ref($e4) . " is expected assign-run/solexa");

my @ds = UR::Context->get_current->resolve_data_sources_for_class_meta_and_rule(
    UR::Object::Type->get("Genome::Model::Event"),
    UR::BoolExpr->resolve_for_class_and_params("Genome::Model::Event", ())
);
my $e2_id = $ds[0]->get_default_dbh->selectrow_array("select min(genome_model_event_id) from genome_model_event where event_type = '$event_type'");
ok($e2_id, "got an id from the database directly: $e2_id");

my $e2 = Genome::Model::Event->get($e2_id);
is(ref($e2),$event_class_name, "new object is sub-classified correctly");



