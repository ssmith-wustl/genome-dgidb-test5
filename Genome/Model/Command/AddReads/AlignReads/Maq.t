#!/gsc/bin/perl

use strict;
use warnings;
use above "Genome"; 
use Test::More tests => 2;
             	
my $event_id = 88961295; # 88986518;	
my $event = Genome::Model::Event->get($event_id);
ok($event, "got an event");

#this is time consuming. comment out for autorun.
#my @m = $event->generate_metrics();
#is(scalar(@m), 6, "got metrics");


