#!/gsc/bin/perl

use strict;
use warnings;

use above 'Workflow';
use above 'EGAP';
use Data::Dumper;
use File::Basename;
use Test::More qw(no_plan);

my $w = Workflow::Model->create_from_xml($ARGV[0] || File::Basename::dirname(__FILE__).'/data/egap_contig.xml');
ok($w, 'workflow object created'); # gotta 'test' something, right?

print join("\n", $w->validate) . "\n";

print $w->as_png("/tmp/test.png");
exit;
