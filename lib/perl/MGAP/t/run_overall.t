#!/gsc/bin/perl

use strict;
use warnings;


#use Test::More qw(no_plan);
use Test::More qw(no_plan);
use above 'Workflow';
use above 'MGAP';
use File::Basename;
use Data::Dumper;

my $w = Workflow::Model->create_from_xml($ARGV[0] || File::Basename::dirname(__FILE__).'/data/mgap.xml');

print join("\n", $w->validate) . "\n";

#print $w->as_png("/tmp/test.png");
#exit;

#my $out = $w->execute(
#    'input' => {
#        'dev flag' => 1,
#        'seq set id' => 43
#    }
#);
##
#$w->wait;
#
#print Data::Dumper->new([$out])->Dump;

done_testing();

