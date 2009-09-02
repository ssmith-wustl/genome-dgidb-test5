#!/gsc/bin/perl

use strict;
use warnings;

use above 'Genome';
use Test::More tests => 2;
use File::Basename;


BEGIN {use_ok('Genome::Model::Tools::ViromeEvent::RepeatMasker::InnerCheckResult');}

#create
my $ocr = Genome::Model::Tools::ViromeEvent::RepeatMasker::InnerCheckResult->create(
                                                                file_to_run => '/gscmnt/sata835/info/medseq/virome/test17/S0_Mouse_Tissue_0_Control/S0_Mouse_Tissue_0_Control.fa.cdhit_out_RepeatMasker/S0_Mouse_Tissue_0_Control.fa.cdhit_out_file3.fa',
                                                                logfile => '/gscmnt/sata835/info/medseq/virome/workflow/logfile.txt',
                                                            );
isa_ok($ocr, 'Genome::Model::Tools::ViromeEvent::RepeatMasker::InnerCheckResult');
#$ocr->execute();
