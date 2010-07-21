#!/gsc/bin/perl

use strict;
use warnings;

use above 'Genome';
use Test::More tests => 2;


BEGIN {use_ok('Genome::Model::Tools::ViromeEvent::BlastN::CheckParseOutput');}

#create
my $cpo = Genome::Model::Tools::ViromeEvent::BlastN::CheckParseOutput->create(
                                                                dir => '/gscmnt/sata835/info/medseq/virome/test17/S0_Mouse_Tissue_0_Control',
                                                            );
isa_ok($cpo, 'Genome::Model::Tools::ViromeEvent::BlastN::CheckParseOutput');
#$cpo->execute();
