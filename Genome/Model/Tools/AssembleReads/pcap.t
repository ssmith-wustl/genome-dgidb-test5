#!/gsc/bin/perl

use strict;
use warnings;
use Test::More tests => 13;

use above 'Genome';
use Genome::Model::Command::Tools::AssembleReads::Pcap;

`rm -rf /gscmnt/936/info/jschindl/pcap_test`;
`cp -rf /gscmnt/936/info/jschindl/pcap_test_backup /gscmnt/936/info/jschindl/pcap_test`;
my $obj = Genome::Model::Command::Tools::AssembleReads::Pcap->create(
								     project_name => 'ES_ASSEMBLY',
								     data_path => '/gscmnt/936/info/jschindl/pcap_test',
#								     data_path => '/tmp/foo2',

								     );

#ok($obj->create_project_directories, "create project dirs works" );

#for my $subdir (qw/phd_dir edit_dir/)
#{
#    ok(-d "/tmp/foo/$subdir", "directory /tmp/foo/$subdir is present");
#}

#ok($obj->dump_reads, "dump reads works");
ok($obj->create_pcap_input_fasta_fof, "pcap fasta fof created");
ok($obj->create_constraint_file, "constraint file created successfully");
ok($obj->run_pcap, "test pcap.rep");
ok($obj->run_bdocs, "test bdocs.rep");
ok($obj->run_bclean, "test bclean.rep");
ok($obj->run_bcontig, "test bcontig.rep");
ok($obj->run_bconsen, "test bconsen.test");
ok($obj->run_bform, "test bform.rep");
ok($obj->create_gap_file, "test create_gap_file");
ok($obj->create_agp_file, "test create_agp_file");
ok($obj->create_sctg_fa_file, "test create_sctg_fa_file");
ok($obj->create_stats_file, "test create_stats_file");
sleep 60;#give stats files time to get created
ok($obj->run_stats, "test run_stats");

