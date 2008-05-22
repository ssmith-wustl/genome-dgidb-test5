
use strict;
use warnings;

use above "Genome";
use Genome::Model::Command::AddReads::PostprocessVariations;
use Genome::Model::Command::AddReads::AnnotateVariations;

use Test::More tests => 4;

my $event_id = 89040994;
my $event = Genome::Model::Event->get($event_id);
ok($event, "got a test event");
isa_ok($event,'Genome::Model::Command::AddReads::PostprocessVariations');

my $av = Genome::Model::Command::AddReads::AnnotateVariations->execute(
    model_id => $event->model_id,
    ref_seq_id => $event->ref_seq_id,
);
ok($av, "successfully ran the step to annotate the variations");

my @outputs = $av->outputs();
is(scalar(@outputs),1,"got expected count");

1;

