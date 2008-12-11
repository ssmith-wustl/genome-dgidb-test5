#!/gsc/bin/perl

use strict;
use warnings;

use above 'Workflow';

use Workflow::Simple;


my $xml_file   = $ARGV[0] || 'data/pap_outer.xml';
my $fasta_file = $ARGV[1] || 'data/B_coprocola.fasta';

my $output = run_workflow_lsf(
                              $xml_file,
                              'fasta file'       => $fasta_file,
                              'chunk size'       => 10,
                              'dev flag'         => 1,
                              'biosql namespace' => 'MGAP',
                              'gram stain'       => 'negative',
                              'report save dir'  => '/gscmnt/temp212/info/annotation/PAP_testing/blast_reports',
                          );


print Data::Dumper->new([$output])->Dump;
