#!/gsc/bin/perl

use strict;
use warnings;

use above 'Workflow';

use Workflow::Simple;


my $xml_file   = $ARGV[0] || 'data/egap.xml';

my $output = run_workflow_lsf(
                              $xml_file,
                              'seq set id'    => 73,
                              'fgenesh model' => '/gsc/pkg/bio/softberry/installed/sprog/C_elegans', 
                              'SNAP model'    => '/gsc/pkg/bio/snap/installed/HMM/C.elegans.hmm', 
                          );


print Data::Dumper->new([$output,\@Workflow::Simple::ERROR])->Dump;

