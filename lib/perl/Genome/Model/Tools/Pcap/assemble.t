#!/gsc/bin/perl

use strict;
use warnings;
use Test::More tests => 17;
use above 'Genome';
use Genome::Model::Tools::Pcap::Assemble;
use Data::Dumper;

my $obj = Genome::Model::Tools::Pcap::Assemble->create
    (
     project_name       => 'Proteus_penneri_ATCC_35198',
     disk_location      => '/gsc/var/cache/testsuite/data/Genome-Model-Tools-AssemblReads-Pcap',
     parameter_setting  => 'RELAXED',
     assembly_version   => '1.0',
     assembly_date      => '080509',
     read_prefixes      => 'PPBA',
     pcap_run_type      => 'NORMAL',
    );
 
$obj->_project_path();  # Makes the object discover it's project_path
$obj->delete_completed_assembly;  # Clean out the cruft from any past semi-completed test

ok($obj->create_project_directories, "created project dirs");
#ok($obj->validate_organism_name, "organism name validated"); #SKIP .. NOT ALL ASSEMBLIES HAVE VALID ORG NAME
ok($obj->copy_test_data_set, "test data set copied");
ok($obj->create_pcap_input_fasta_fof, "pcap fasta fof created");
ok($obj->create_constraint_file, "constraint file created successfully");
ok($obj->resolve_pcap_run_type, "pcap run type resolved");
ok($obj->run_pcap, "test pcap.rep");
ok($obj->run_bdocs, "test bdocs.rep");
ok($obj->run_bclean, "test bclean.rep");
ok($obj->run_bcontig, "test bcontig.rep");
ok($obj->check_for_results_file, "test check for results file");
ok($obj->run_bconsen, "test bconsen.test");
ok($obj->run_bform, "test bform.rep");
ok($obj->create_gap_file, "test create_gap_file");
ok($obj->create_agp_file, "test create_agp_file");
ok($obj->create_sctg_fa_file, "test create_sctg_fa_file");
ok($obj->add_wa_tags_to_ace, "test add WA tags to ace");
ok($obj->delete_completed_assembly, "remove this assembly");
#ok($obj->clean_up, "test clean up step");
