#!/gsc/bin/perl

use strict;
use warnings;

use above 'Genome';
use Test::More tests => 2;


BEGIN {use_ok('Genome::Model::Tools::ViromeEvent::BlastHumanGenome::OuterCheckOutput');}

#create
my $co = Genome::Model::Tools::ViromeEvent::BlastHumanGenome::OuterCheckOutput->create(
                                                                dir => '/gscmnt/sata835/info/medseq/virome/test17/S0_Mouse_Tissue_0_Control',
                                                                logfile => 'foo.txt',
                                                            );
isa_ok($co, 'Genome::Model::Tools::ViromeEvent::BlastHumanGenome::OuterCheckOutput');
#$co->execute();
