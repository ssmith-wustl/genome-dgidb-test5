#!/gsc/bin/perl

# This test confirms the ability to create a processing profile and then create
# a genome model using that processing profile

use strict;
use warnings;

use Data::Dumper;
use above "Genome";
use Command;
use Test::More tests => 69;
use Test::Differences;
use File::Path;

use FindBin qw($Bin);
my $genotype_submission_file = "$Bin/t/test_genotype_submission.tsv";
my $watson_test_data = "$Bin/t/test_watson.tsv";
my $venter_test_data = "$Bin/t/test_venter.tsv";

$ENV{UR_DBI_NO_COMMIT} = 1;
$ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;

# Attributes for new model and processing profile

my $indel_finder = 'maq0_6_3';
my $model_name = "test_$ENV{USER}";
my $sample = 'H_GV-933124G-skin1-9017g';
my $dna_type = 'genomic dna';
my $align_dist_threshold = '0';
my $reference_sequence = 'refseq-for-test';
my $genotyper = 'maq0_6_3';
my $read_aligner = 'maq0_6_3';
my $pp_name = 'testing';

diag('test command create for a processing profile short reads');
my $create_pp_command= Genome::Model::Command::Create::ProcessingProfile::ShortRead->create(
     indel_finder          => $indel_finder,
     dna_type              => $dna_type,
     align_dist_threshold  => $align_dist_threshold,
     reference_sequence    => $reference_sequence,
     genotyper             => $genotyper ,
     read_aligner          => $read_aligner,
     profile_name          => $pp_name,
     bare_args => [],
 );


# check and create the processing profile
isa_ok($create_pp_command,'Genome::Model::Command::Create::ProcessingProfile::ShortRead');
ok($create_pp_command->execute(), 'execute processing profile create');     

# Get it and make sure there is one
my @processing_profiles = Genome::ProcessingProfile::ShortRead->get(name => $pp_name);
is(scalar(@processing_profiles),1,'expected one processing profile');

# check the type
my $pp = $processing_profiles[0];
isa_ok($pp ,'Genome::ProcessingProfile::ShortRead');

# Test the properties were set and the accessors functionality
is($pp->indel_finder_name,$indel_finder,'processing profile indel_finder accessor');
is($pp->dna_type,$dna_type,'processing profile dna_type accessor');
is($pp->align_dist_threshold,$align_dist_threshold,'processing profile align_dist_threshold accessor');
is($pp->reference_sequence_name,$reference_sequence,'processing profile reference_sequence accessor');
is($pp->genotyper_name,$genotyper,'processing profile genotyper accessor');
is($pp->read_aligner_name,$read_aligner,'processing profile read_aligner accessor');
is($pp->name,$pp_name,'processing profile name accessor');


diag('test command create for a genome model');
my $create_command= Genome::Model::Command::Create::Model->create( 
    model_name              => $model_name,
    sample                  => $sample,
    processing_profile_name => $pp_name,
    bare_args               => [],
);
    
isa_ok($create_command,'Genome::Model::Command::Create::Model');

my $result = $create_command->execute();
ok($result, 'execute genome-model create');

my $genome_model_id = $result->id;

my @models = Genome::Model->get($genome_model_id);
is(scalar(@models),1,'expected one model');

my $model = $models[0];
isa_ok($model,'Genome::Model');

is($model->genome_model_id,$genome_model_id,'model genome_model_id accessor');
is($model->indel_finder_name,$indel_finder,'model indel_finder accessor');
is($model->name,$model_name,'model model_name accessor');
is($model->sample_name,$sample,'model sample accessor');
is($model->dna_type,$dna_type,'model dna_type accessor');
is($model->align_dist_threshold,$align_dist_threshold,'model align_dist_threshold accessor');
is($model->reference_sequence_name,$reference_sequence,'model reference_sequence accessor');
is($model->genotyper_name,$genotyper,'model genotyper accessor');
is($model->read_aligner_name,$read_aligner,'model read_aligner accessor');

UR::Context->_sync_databases(); 


diag('test create for a genome model object');
$model_name = 'model_name_here';
my $sample_name = 'sample_name_here';
my %params = (
    name => $model_name,
    sample_name => $sample_name,
    processing_profile_id   => $pp->id, # cannot access pp properties without the id here
);
my $obj = Genome::Model->create(%params);
ok($obj, 'creation worked');
isa_ok($obj ,'Genome::Model::ShortRead');

# Test the accessors through the processing profile
diag('Test accessing model for processing profile properties...');
is($obj->indel_finder_name,$indel_finder,'indel_finder accessor');
is($obj->dna_type,$dna_type,'dna_type accessor');
is($obj->align_dist_threshold,$align_dist_threshold,'align_dist_threshold accessor');
is($obj->reference_sequence_name,$reference_sequence,'reference_sequence accessor');
is($obj->genotyper_name,$genotyper,'genotyper accessor');
is($obj->read_aligner_name,$read_aligner,'read_aligner accessor');
is($obj->name,$model_name,'name accessor');
is($obj->type_name,'short read','type name accessor');

# test the model accessors
diag('Test accessing model for model properties...');
is($obj->name,$model_name,'model name accessor');
is($obj->sample_name,$sample_name,'sample name accessor');
is($obj->processing_profile_id,$pp->id,'processing profile id accessor');

diag('subclassing tests - test create for a processing profile object of each subclass');

# Test creation for a processing profile of many different types
my $ppsr = Genome::ProcessingProfile->create(type_name => 'short read');
ok($ppsr, 'creation worked for short read processing profile');
isa_ok($ppsr ,'Genome::ProcessingProfile::ShortRead');

my $ppdns = Genome::ProcessingProfile->create(type_name => 'de novo sanger');
ok($ppdns, 'creation worked de novo sanger processing profile');
isa_ok($ppdns ,'Genome::ProcessingProfile::DeNovoSanger');

my $ppirs = Genome::ProcessingProfile->create(type_name => 'imported reference sequence');
ok($ppirs, 'creation worked imported reference sequence processing profile');
isa_ok($ppirs ,'Genome::ProcessingProfile::ImportedReferenceSequence');

my $ppivw = Genome::ProcessingProfile->create(type_name => 'imported variants watson');
ok($ppivw, 'creation worked imported variants watson processing profile');
isa_ok($ppivw ,'Genome::ProcessingProfile::ImportedVariantsWatson');

my $ppivv = Genome::ProcessingProfile->create(type_name => 'imported variants venter');
ok($ppivv, 'creation worked imported variants venter processing profile');
isa_ok($ppivv,'Genome::ProcessingProfile::ImportedVariantsVenter');

my $ppma = Genome::ProcessingProfile->create(type_name => 'micro array');
ok($ppma, 'creation worked micro array processing profile');
isa_ok($ppma ,'Genome::ProcessingProfile::MicroArray');

my $ppmai = Genome::ProcessingProfile->create(type_name => 'micro array illumina');
ok($ppmai, 'creation worked micro array illumina processing profile');
isa_ok($ppmai ,'Genome::ProcessingProfile::MicroArrayIllumina');

my $ppmaa = Genome::ProcessingProfile->create(type_name => 'micro array affymetrix');
ok($ppmaa, 'creation worked micro array affymetrix processing profile');
isa_ok($ppmaa ,'Genome::ProcessingProfile::MicroArrayAffymetrix');

# Test creation for the corresponding models
diag('subclassing tests - test create for a genome model object of each subclass');
my $gmsr = Genome::Model->create(processing_profile_id => $ppsr->id,
                                 name => 'short read test');
ok($gmsr, 'creation worked for short read model');
isa_ok($gmsr ,'Genome::Model::ShortRead');
my $gmdns = Genome::Model->create(processing_profile_id => $ppdns->id,
                                 name => 'de novo sanger test');
ok($gmdns, 'creation worked de novo sanger model');
isa_ok($gmdns ,'Genome::Model::DeNovoSanger');

my $gmirs = Genome::Model->create(processing_profile_id => $ppirs->id,
                                 name => 'imported reference sequence test');
ok($gmirs, 'creation worked imported reference sequence model');
isa_ok($gmirs ,'Genome::Model::ImportedReferenceSequence');

my $gmivw = Genome::Model->create(processing_profile_id => $ppivw->id,
                                 instrument_data => $watson_test_data,
                                 name => 'imported variants watson test1');
ok($gmivw, 'creation worked imported variants watson model');
isa_ok($gmivw ,'Genome::Model::ImportedVariantsWatson');

my $gmivv = Genome::Model->create(processing_profile_id => $ppivv->id,
                                 instrument_data => $venter_test_data,
                                 name => 'imported variants venter test1');
ok($gmivv, 'creation worked imported variants venter model');
isa_ok($gmivv ,'Genome::Model::ImportedVariantsVenter');

my $gmma = Genome::Model::MicroArray->create(processing_profile_id => $ppma->id,
                                 name => 'micro array test',
                                 instrument_data => $genotype_submission_file 
                                );
ok($gmma, 'creation worked micro array processing profile');
isa_ok($gmma ,'Genome::Model::MicroArray');

my $gmmai = Genome::Model::MicroArray->create(processing_profile_id => $ppmai->id,
                                 name => 'micro array illumina test',
                                 instrument_data => $genotype_submission_file 
                                );
ok($gmmai, 'creation worked micro array illumina processing profile');
isa_ok($gmmai ,'Genome::Model::MicroArrayIllumina');

my $gmmaa = Genome::Model::MicroArray->create(processing_profile_id => $ppmaa->id,
                                 name => 'micro array affymetrix test',
                                 instrument_data => $genotype_submission_file 
                                );
ok($gmmaa, 'creation worked micro array affymetrix processing profile');
isa_ok($gmmaa ,'Genome::Model::MicroArrayAffymetrix');

