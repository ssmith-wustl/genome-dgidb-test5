#!/gsc/bin/perl

use strict;
use warnings;

use above 'Genome';
use Test::More tests => 2;


BEGIN {use_ok('Genome::Model::Tools::ViromeEvent::RepeatMasker::OuterCheckResult');}

#create
my $ocr = Genome::Model::Tools::ViromeEvent::RepeatMasker::OuterCheckResult->create(
                                                                dir     => '/gscmnt/sata835/info/medseq/virome/test17/S0_Mouse_Tissue_0_Control',
                                                                logfile => '/gscmnt/sata835/info/medseq/virome/workflow/logfile.txt',
                                                            );
isa_ok($ocr, 'Genome::Model::Tools::ViromeEvent::RepeatMasker::OuterCheckResult');
$ocr->execute();
