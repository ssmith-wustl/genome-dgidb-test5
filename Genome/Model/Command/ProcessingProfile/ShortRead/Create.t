#!/gsc/bin/perl

# This tests processing profile short reads creation

use strict;
use warnings;

use Data::Dumper;
use above "Genome";
use Command;
use Test::More qw(no_plan);

$ENV{UR_DBI_NO_COMMIT} = 1;
$ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;

my $indel_finder = 'maq0_6_3';
my $sample = 'H_GV-933124G-skin1-9017g';
my $dna_type = 'genomic dna';
my $align_dist_threshold = '0';
my $reference_sequence = 'refseq-for-test';
my $genotyper = 'maq0_6_3';
my $read_aligner = 'maq0_6_3';
my $pp_name = 'testing';

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
is($pp->indel_finder_name,$indel_finder,'indel_finder accessor');
is($pp->dna_type,$dna_type,'dna_type accessor');
is($pp->align_dist_threshold,$align_dist_threshold,'align_dist_threshold accessor');
is($pp->reference_sequence_name,$reference_sequence,'reference_sequence accessor');
is($pp->genotyper_name,$genotyper,'genotyper accessor');
is($pp->read_aligner_name,$read_aligner,'read_aligner accessor');
is($pp->name,$pp_name,'name accessor');


