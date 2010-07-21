#!/gsc/bin/perl

use strict;
use warnings;

use above 'Genome';
use Test::More tests => 2;


BEGIN {use_ok('Genome::Model::Tools::ViromeEvent::BlastHumanGenome::SplitGivenNumberReads');}

#create
my $sgnr = Genome::Model::Tools::ViromeEvent::BlastHumanGenome::SplitGivenNumberReads->create(
                                                                dir => '/gscmnt/sata835/info/medseq/virome/test17/S0_Mouse_Tissue_0_Control',
                                                            );
isa_ok($sgnr, 'Genome::Model::Tools::ViromeEvent::BlastHumanGenome::SplitGivenNumberReads');
#$sgnr->execute();
