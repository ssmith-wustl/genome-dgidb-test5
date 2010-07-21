#!/gsc/bin/perl

use strict;
use warnings;

use above 'Genome';
use Test::More tests => 2;
use File::Basename;


BEGIN {use_ok('Genome::Model::Tools::ViromeEvent::BlastX_NT::OuterCheckOutput');}
my @ffb = ('S0_Mouse_Tissue_0_Control.BNFiltered.fa_file0.TBXNTfiltered.fa',
          'S0_Mouse_Tissue_0_Control.BNFiltered.fa_file1.TBXNTfiltered.fa');
#create
my $ocr = Genome::Model::Tools::ViromeEvent::BlastX_NT::OuterCheckOutput->create(
                                                                files_for_blast => \@ffb, 
                                                                logfile => '/gscmnt/sata835/info/medseq/virome/workflow/logfile.txt',
                                                            );
isa_ok($ocr, 'Genome::Model::Tools::ViromeEvent::BlastX_NT::OuterCheckOutput');
#$ocr->execute();
