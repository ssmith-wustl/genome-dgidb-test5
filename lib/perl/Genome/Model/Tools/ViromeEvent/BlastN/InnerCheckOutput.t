#!/gsc/bin/perl

use strict;
use warnings;

use above 'Genome';
use Test::More tests => 2;


BEGIN {use_ok('Genome::Model::Tools::ViromeEvent::BlastN::InnerCheckOutput');}

#create
my $co = Genome::Model::Tools::ViromeEvent::BlastN::InnerCheckOutput->create(
                                                                file_to_run => '/gscmnt/sata835/info/medseq/virome/test17/S0_Mouse_Tissue_0_Control/S0_Mouse_Tissue_0_Control.fa.cdhit_out_RepeatMasker/S0_Mouse_Tissue_0_Control.fa.cdhit_out_file3.fa',
                                                                logfile => '/gscmnt/sata835/info/medseq/virome/workflow/logfile.txt',
                                                            );
isa_ok($co, 'Genome::Model::Tools::ViromeEvent::BlastN::InnerCheckOutput');
