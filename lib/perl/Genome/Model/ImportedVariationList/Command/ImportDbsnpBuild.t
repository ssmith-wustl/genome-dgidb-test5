#!/usr/bin/env perl 
use strict;                                                                                                       
use warnings;                                                                                                     
use above "Genome";                                                                                               
use Test::More;

$ENV{UR_DBI_NO_COMMIT} = 1;                                                                                       
$ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;     

use_ok("Genome::Model::ImportedVariationList::Command::ImportDbsnpBuild");

my $reference_sequence_build = Genome::Model::Build::ReferenceSequence->get_by_name('g1k-human-build37');

my $import_dbsnp_build = Genome::Model::ImportedVariationList::Command::ImportDbsnpBuild->create(
    vcf_file_url => 'https://gscweb.gsc.wustl.edu/gscmnt/ams1102/info/test_suite_data/Genome-Model-Tools-Dbsnp-Import-Vcf/VCF/4.0/00-All.vcf.gz',
    version => "135",
    reference_sequence_build => $reference_sequence_build ,
);

ok($import_dbsnp_build->execute(), "Dbsnp build import completed");

my $build = $import_dbsnp_build->build;
isa_ok($build, "Genome::Model::Build::ImportedVariationList"); 

ok($build->snv_result, "The build has a snv result attached to it");
is($build->version, 135);
is($build->source_name, "dbsnp", "Source name is set properly");

done_testing();
