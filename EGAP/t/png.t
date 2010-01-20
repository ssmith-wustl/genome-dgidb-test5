#!/gsc/bin/perl

use strict;
use warnings;

use above 'Workflow';
use Data::Dumper;

my $w = Workflow::Model->create_from_xml($ARGV[0] || 'data/egap_contig.xml');

print join("\n", $w->validate) . "\n";

print $w->as_png("/tmp/test.png");
exit;
