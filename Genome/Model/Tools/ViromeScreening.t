#!/gsc/bin/perl

use strict;
use warnings;

use above 'Genome';
use Test::More tests => 2;


BEGIN {use_ok('Genome::Model::Tools::ViromeScreening');}

my ($fasta_file,$barcode_file,$dir,$logfile) = (  
                                                            '/gscmnt/sata835/info/medseq/virome/test_kathy/Titanium17_2009_05_05_set0.fna',                                                     
                                                            '/gscmnt/sata835/info/medseq/virome/test_kathy/454_Sequencing_log_Titanium_17.txt',                                                   
                                                            '/gscmnt/sata835/info/medseq/virome/test_kathy',
                                                            '/gscmnt/sata835/info/medseq/virome/test_kathy/logfile.txt'
                                                        );                                                       

#create
my $vs = Genome::Model::Tools::ViromeScreening->create(
                                                                fasta_file      => $fasta_file,
                                                                barcode_file    => $barcode_file,
                                                                dir             => $dir, 
                                                                logfile         => $logfile,
                                                            );
isa_ok($vs, 'Genome::Model::Tools::ViromeScreening');
#$vs->execute();
