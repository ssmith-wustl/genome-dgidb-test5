#!/gsc/bin/perl

use strict;
use warnings;
use Test::More tests => 16;
use above 'Genome';
use Genome::Model::Tools::AssembleReads::Pcap;
use Data::Dumper;

my $obj = Genome::Model::Tools::AssembleReads::Pcap->create
    (
     project_name       => 'Proteus_penneri_ATCC_35198',
     disk_location      => '/gsc/var/cache/testsuite/data/Genome-Model-Tools-AssemblReads-Pcap',
     parameter_setting  => 'RELAXED',
     assembly_version   => '1.0',
     assembly_date      => '080509',
     read_prefixes      => 'PPBA',
     pcap_run_type      => 'NORMAL',
    );
 

ok($obj->create_project_directories, "created project dirs");
ok($obj->validate_organism_name, "organism name validated");
ok($obj->resolve_data_needs, "data needs resolved");
ok($obj->create_pcap_input_fasta_fof, "pcap fasta fof created");
ok($obj->create_constraint_file, "constraint file created successfully");
ok($obj->resolve_pcap_run_type, "pcap run type resolved");
ok($obj->run_pcap, "test pcap.rep");
ok($obj->run_bdocs, "test bdocs.rep");
ok($obj->run_bclean, "test bclean.rep");
ok($obj->run_bcontig, "test bcontig.rep");
ok($obj->run_bconsen, "test bconsen.test");
ok($obj->run_bform, "test bform.rep");
ok($obj->create_gap_file, "test create_gap_file");
ok($obj->create_agp_file, "test create_agp_file");
ok($obj->create_sctg_fa_file, "test create_sctg_fa_file");
ok($obj->delete_completed_assembly, "remove this assembly");

