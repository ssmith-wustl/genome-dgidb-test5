#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";

use Test::More tests => 3;

my $event =  Genome::Model::Event->get(92635831);

ok(my $log_dir = $event->resolve_log_directory, "got a log directory");
ok(my $desc = $event->desc, "got a desc");
ok(scalar($event->invalid)==0, 'Event is valid lol');


