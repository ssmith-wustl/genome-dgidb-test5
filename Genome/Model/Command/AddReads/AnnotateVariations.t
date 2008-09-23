
use strict;
use warnings;

use above "Genome";
use Genome::Model::Command::AddReads::PostprocessVariations;

use Test::More tests => 2;

my $event_id = 91364902;
my $event = Genome::Model::Event->get($event_id);
ok($event, "got a test event");
isa_ok($event,'Genome::Model::Command::AddReads::PostprocessVariations');



1;

