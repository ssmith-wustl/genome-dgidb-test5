#!/gsc/bin/perl

use strict;
use warnings;

use above 'Genome';
use Test::More tests => 2;


BEGIN {use_ok('Genome::Model::Tools::ViromeEvent::BlastN::CheckOutput');}

#create
my $co = Genome::Model::Tools::ViromeEvent::BlastN::CheckOutput->create(
                                                                dir => '/gscmnt/sata835/info/medseq/virome/test_mini/S0_Mouse_Tissue_0_Control',
                                                            );
isa_ok($co, 'Genome::Model::Tools::ViromeEvent::BlastN::CheckOutput');
#$co->execute();
