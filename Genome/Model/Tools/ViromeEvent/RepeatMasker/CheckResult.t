#!/gsc/bin/perl

use strict;
use warnings;

use above 'Genome';
use Test::More tests => 2;


BEGIN {use_ok('Genome::Model::Tools::ViromeEvent::RepeatMasker::CheckResult');}

#create
my $cr = Genome::Model::Tools::ViromeEvent::RepeatMasker::CheckResult->create(
                                                                dir => '/gscmnt/sata835/info/medseq/virome/test_mini/S0_Mouse_Tissue_0_Control',
                                                            );
isa_ok($cr, 'Genome::Model::Tools::ViromeEvent::RepeatMasker::CheckResult');
#$cr->execute();
