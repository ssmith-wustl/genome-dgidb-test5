#!/gsc/bin/perl

use strict;
use warnings;

use lib '/gscuser/mjohnson/bioperl-svn/bioperl-live';
use lib '/gscuser/mjohnson/bioperl-svn/bioperl-run';

use above 'Workflow';
use Data::Dumper;

my $w = Workflow::Model->create_from_xml($ARGV[0] || 'data/mgap.xml');

print join("\n", $w->validate) . "\n";

#print $w->as_png("/tmp/test.png");
#exit;

my $out = $w->execute(
    'input' => {
        'dev flag' => 1,
        'seq set id' => 43
    }
);

$w->wait;

print Data::Dumper->new([$out])->Dump;

