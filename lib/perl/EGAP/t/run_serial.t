#!/gsc/bin/perl

use strict;
use warnings;

use above 'Workflow';
use above 'EGAP';
use Data::Dumper;
use File::Basename;
use Test::More qw(no_plan);


SKIP: {
    skip "run manually by setting RUNEGAP=1", 1 unless $ENV{RUNEGAP};
my $w = Workflow::Model->create_from_xml($ARGV[0] || File::Basename::dirname(__FILE__).'/data/egap.xml');

ok($w, 'workflow object is defined');
#$w->is_valid();
my @errors = $w->validate;
#die 'Too many problems: ' . join("\n", @errors) unless $w->is_valid();
unless($w->is_valid() ){
    diag('too many problems: ' . join("\n",@errors));
}

my $out = $w->execute(
                      'input ' => {
                                   'seq set id'    => 73,
                                   'fgenesh model' => '/gsc/pkg/bio/softberry/installed/sprog/C_elegans', 
                                   'SNAP model'    => '/gsc/pkg/bio/snap/installed/HMM/C.elegans.hmm', 
                      }
                     );

$w->wait();

print Data::Dumper->new([$out])->Dump;
}

