
use strict;
use warnings;

use above "Genome";
use Genome::Model::Command::Build::ReferenceAlignment::PostprocessVariations;
use Genome::Model::Command::Build::ReferenceAlignment::FilterVariations;

use Test::More tests => 3;
die "This test is broken until there exists a Genome::Model::Command::Build::ReferenceAlignment event that has an associated row in the GENOME_MODEL_BUILD table";

my $event_id = 91364902;
my $event = Genome::Model::Event->get($event_id);
ok($event, "got a test event");
isa_ok($event,'Genome::Model::Command::Build::ReferenceAlignment::PostprocessVariations');

my $parent_event_id = 90160434;
my $parent_event = Genome::Model::Event->get($parent_event_id);
ok($parent_event, "Got a parent test event");
isa_ok($event, 'Genome::Model::Command::Build::ReferenceAlignment');
is($parent_event->model_id, $event->model_id, 'model_id from both test events are the same');

my $av = Genome::Model::Command::Build::ReferenceAlignment::PostprocessVariations->create(
    model_id => $event->model_id,
    ref_seq_id => $event->ref_seq_id,
    prior_event_id => $event->id,
    parent_event_id => $parent_event->id,
);

ok($av->snp_output_file, "snp output file accessor works" . $av->snp_output_file);

1;

