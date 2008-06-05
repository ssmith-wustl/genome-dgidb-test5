#!/gsc/bin/perl

use strict;
use warnings;
#use Test::More tests => 1;
use Test::More;
plan "skip_all";
use above 'Genome';
use Genome::Model::Tools::AssembleReads::Pcap;
use Data::Dumper;

my $obj = Genome::Model::Tools::AssembleReads::Pcap->create
    (
     project_name       => 'Proteus_penneri_ATCC_35198',
     disk_location      => '/gscmnt/820/finishing/assembly',
     parameter_setting  => 'RELAXED',
     assembly_version   => '1.0',
     assembly_date      => '080509',
     existing_data_only => 'YES',
     pcap_run_type      => 'RAW_454',
    );
 

ok($obj->create_project_directories, "created project dirs");
#ok($obj->resolve_data_needs, "data needs resolved");
#don't need this #ok($obj->get_read_prefixes, "got read prefixes");
#don't need this #ok($obj->dump_reads, "dump reads works");
#ok($obj->create_fake_phds, "made fake phds");
#ok($obj->create_pcap_input_fasta_fof, "pcap fasta fof created");
#ok($obj->create_constraint_file, "constraint file created successfully");
#ok($obj->resolve_pcap_run_type, "pcap run type resolved");
#ok($obj->run_pcap, "test pcap.rep");
#ok($obj->run_bdocs, "test bdocs.rep");
#ok($obj->run_bclean, "test bclean.rep");
#ok($obj->run_bcontig, "test bcontig.rep");
#ok($obj->run_bconsen, "test bconsen.test");
#ok($obj->run_bform, "test bform.rep");
#ok($obj->create_gap_file, "test create_gap_file");
#ok($obj->create_agp_file, "test create_agp_file");
#ok($obj->create_sctg_fa_file, "test create_sctg_fa_file");
#ok($obj->create_stats_files, "test create_stats_file");
#sleep 120;#give stats files time to get created
   #old stats
#ok($obj->create_post_asm_files, "make insertsizes and readinfo files");
#ok($obj->create_stats, "test run_stats");
