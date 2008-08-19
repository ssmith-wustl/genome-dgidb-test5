#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";

use Test::More tests => 20;

# prevent the ugly messages when we test known error conditions
$SIG{__DIE__} = sub {};

diag("testing sub-classification by event_type formula...");

my $event_type = "genome-model add-reads align-reads maq";
my $event_class_name = "Genome::Model::Command::AddReads::AlignReads::Maq";
my ($pp) = sort { $a->id <=> $b->id } grep {$_->read_aligner_name eq 'maq0_6_5' } Genome::ProcessingProfile::ShortRead->get();
my $m = Genome::Model->create(id => -1, sample_name => "test_case_sample$$",  processing_profile => $pp);
my $r = Genome::RunChunk->create(-1, sequencing_platform => 'solexa');

my $e1 = Genome::Model::Event->create(event_type => $event_type, id => -2, model_id => $m->id, run_id => $r->id);
ok($e1, "created an object");
isa_ok($e1,$event_class_name);

my $tmpdir = $e1->base_temp_directory;
ok($tmpdir, "got a base temp directory $tmpdir");
ok(-d $tmpdir, "it exists");
my $tmpdir1 = $e1->create_temp_directory('foo');
ok(-d $tmpdir1,"got a dir $tmpdir1");
my $tmpdir4 = $e1->create_temp_directory();
ok(-d $tmpdir4,"got a dir $tmpdir4");
my $tmpdir2 = eval { $e1->create_temp_directory('foo'); };
chomp $@;
ok($@, "correctly failed to re-create named temp file: $@");
my $tmpdir3 = $e1->create_temp_directory();
ok(-d $tmpdir3,"got a dir $tmpdir1");
my ($tmpfh, $tmpname)= $e1->create_temp_file("bar");
ok($tmpfh, "made file $tmpfh $tmpname");
my $value1 = rand();
$tmpfh->print($value1);
$tmpfh->close;
my $tmpfh2 = $e1->open_file("bar_bar",$tmpname);
my $value2 = $tmpfh2->getline;
$tmpfh2->close;
is($value2,$value1,"values match");

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



