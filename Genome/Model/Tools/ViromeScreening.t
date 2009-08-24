#!/gsc/bin/perl

use strict;
use warnings;

use above 'Genome';
use Test::More tests => 2;


BEGIN {use_ok('Genome::Model::Tools::ViromeScreening');}

my ($xml_file,$fasta_file,$log_file,$dir) = ('/gscmnt/sata835/info/medseq/virome/workflow/virome.xml',
                                             '/gscmnt/sata835/info/medseq/virome/test_mini/Titanium17_2009_05_05_set0.fna',                                                     
                                             '/gscmnt/sata835/info/medseq/virome/test_mini/454_Sequencing_log_Titanium_17.txt',                                                   
                                             '/gscmnt/sata835/info/medseq/virome/test_mini');                                                       

#create
my $vs = Genome::Model::Tools::ViromeScreening->create(
                                                                workflow_xml => $xml_file,
                                                                fasta_file => $fasta_file,
                                                                log_file => $log_file,
                                                                dir        => $dir, 
                                                            );
isa_ok($vs, 'Genome::Model::Tools::ViromeScreening');
#$vs->execute();
