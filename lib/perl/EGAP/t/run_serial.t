#!/gsc/bin/perl

use strict;
use warnings;

use above 'Workflow';
use Data::Dumper;

my $w = Workflow::Model->create_from_xml($ARGV[0] || 'data/egap.xml');

my @errors = $w->validate;
die 'Too many problems: ' . join("\n", @errors) unless $w->is_valid();

my $out = $w->execute(
                      'input ' => {
                                   'seq set id'    => 73,
                                   'fgenesh model' => '/gsc/pkg/bio/softberry/installed/sprog/C_elegans', 
                                   'SNAP model'    => '/gsc/pkg/bio/snap/installed/HMM/C.elegans.hmm', 
                      }
                     );

$w->wait();

print Data::Dumper->new([$out])->Dump;

