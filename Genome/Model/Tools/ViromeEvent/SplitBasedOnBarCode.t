#!/gsc/bin/perl

use strict;
use warnings;

use above 'Genome';
use Test::More tests => 2;


BEGIN {use_ok('Genome::Model::Tools::ViromeEvent::SplitBasedOnBarCode');}

#create
my $sbob = Genome::Model::Tools::ViromeEvent::SplitBasedOnBarCode->create(
                                                                dir         => '/gscmnt/sata835/info/medseq/virome/test17',
                                                                fasta_file  => '/gscmnt/sata835/info/medseq/virome/test17/Titanium17_2009_05_05_set0.fna',
                                                                barcode_file=> '/gscmnt/sata835/info/medseq/virome/test17/454_Sequencing_log_Titanium_17.txt',
                                                                logfile     => '/gscmnt/sata835/info/medseq/virome/workflow/logfile.txt',
                                                            );
isa_ok($sbob, 'Genome::Model::Tools::ViromeEvent::SplitBasedOnBarCode');
#$sbob->execute();
