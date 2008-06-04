#!/gsc/bin/perl

# This test confirms the ability to create a processing profile and then create
# a genome model using that processing profile
# The test also contains checks to ensure the code-level name uniqueness and
# functional uniqueness constraints are working

use strict;
use warnings;

use Data::Dumper;
use above "Genome";
use Command;
use Test::More tests => 32;
use Test::Differences;

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

######## test command processing profile short reads create. ########
my $create_pp_command= Genome::Model::Command::ProcessingProfile::ShortRead::Create->create(
     indel_finder          => $indel_finder,
     dna_type              => $dna_type,
     align_dist_threshold  => $align_dist_threshold,
     reference_sequence    => $reference_sequence,
     genotyper             => $genotyper ,
     read_aligner          => $read_aligner,
	 profile_name		   => $pp_name,	
     bare_args => [],
 );


# check and create the processing profile
isa_ok($create_pp_command,'Genome::Model::Command::ProcessingProfile::ShortRead::Create');
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


######## test command create for a genome model ########
my $create_command= Genome::Model::Command::Create->create( 
  	model_name            	=> $model_name,
    sample                  => $sample,
	processing_profile_name => $pp_name,
	bare_args 				=> [],
);
    
isa_ok($create_command,'Genome::Model::Command::Create');

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

######## Test enforced name uniqueness ########
$genotyper = 'maq0_6_4';
$read_aligner = 'maq0_6_4';
my $create_pp_command_name_unique= Genome::Model::Command::ProcessingProfile::ShortRead::Create->create(
     indel_finder          => $indel_finder,
     dna_type              => $dna_type,
     align_dist_threshold  => $align_dist_threshold,
     reference_sequence    => $reference_sequence,
     genotyper             => $genotyper ,
     read_aligner          => $read_aligner,
	 profile_name		   => $pp_name,	
     bare_args => [],
 );

# Check to make sure a processing profile with the same name exists already
@processing_profiles = Genome::ProcessingProfile::ShortRead->get(name => $pp_name);
is(scalar(@processing_profiles),1,'expected one processing profile before attempted dupe creation');

# Attempt to create a processing profile with the same name but a different
# quality, we expect this to fail due to enforced name uniqueness
isa_ok($create_pp_command_name_unique,'Genome::Model::Command::ProcessingProfile::ShortRead::Create');
diag('');
diag('Should see two error lines below since we cannot create a processing profile with the same name as an existing one.');
diag('');
ok(!$create_pp_command_name_unique->execute(), 'Create execution fails due to code level name uniqueness constraints');     

# Check to make sure that after attempted duplicate name creation exactly one processing profile still exists
@processing_profiles = Genome::ProcessingProfile::ShortRead->get(name => $pp_name);
is(scalar(@processing_profiles),1,'expected one processing profile after attempted dupe creation');


######## Test enforced functional uniqueness ########
$genotyper = 'maq0_6_3';
$read_aligner = 'maq0_6_3';
$pp_name = 'testing_again';
my $create_pp_command_functional_unique= Genome::Model::Command::ProcessingProfile::ShortRead::Create->create(
     indel_finder          => $indel_finder,
     dna_type              => $dna_type,
     align_dist_threshold  => $align_dist_threshold,
     reference_sequence    => $reference_sequence,
     genotyper             => $genotyper ,
     read_aligner          => $read_aligner,
	 profile_name		   => $pp_name,	
     bare_args => [],
 );

# Check to make sure a processing profile with the same parameters exists already
my %get_params = 
(
	indel_finder_name          	=> $indel_finder,
    dna_type              		=> $dna_type,
    align_dist_threshold  		=> $align_dist_threshold,
    reference_sequence_name    	=> $reference_sequence,
    genotyper_name             	=> $genotyper ,
    read_aligner_name          	=> $read_aligner,
);
@processing_profiles = Genome::ProcessingProfile::ShortRead->get(%get_params);
is(scalar(@processing_profiles),1,'expected one processing profile before attempted dupe creation');

# We expect this to fail due to enforced functional uniqueness
isa_ok($create_pp_command_functional_unique,'Genome::Model::Command::ProcessingProfile::ShortRead::Create');
diag('');
diag('Should see two error lines below since we cannot create a processing profile with the same functionality as an existing one.');
diag('');
ok(!$create_pp_command_functional_unique->execute(), 'Create execution fails due to code level functional uniqueness constraints');     


# Check to make sure a processing profile with the same parameters still exists 
@processing_profiles = Genome::ProcessingProfile::ShortRead->get(%get_params);
is(scalar(@processing_profiles),1,'expected one processing profile after attempted dupe creation');

