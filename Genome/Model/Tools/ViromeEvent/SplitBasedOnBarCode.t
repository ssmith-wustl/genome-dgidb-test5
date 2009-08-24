#!/gsc/bin/perl

use strict;
use warnings;

use above 'Genome';
use Test::More tests => 2;


BEGIN {use_ok('Genome::Model::Tools::ViromeEvent::SplitBasedOnBarCode');}

#create
my $sbob = Genome::Model::Tools::ViromeEvent::SplitBasedOnBarCode->create(
                                                                dir        => '/gscmnt/sata835/info/medseq/virome/test2',
                                                                fasta_file => '/gscmnt/sata835/info/medseq/virome/test2/Titanium9_2009_03_06_set0.fna',
                                                                log_file   => '/gscmnt/sata835/info/medseq/virome/test2/454_Sequencing_log_Titanium9.txt',
                                                            );
isa_ok($sbob, 'Genome::Model::Tools::ViromeEvent::SplitBasedOnBarCode');
#$sbob->execute();
