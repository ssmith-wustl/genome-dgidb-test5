#!/gsc/bin/perl

# This test confirms the ability to create a processing profile and then create
# a genome model using that processing profile

use strict;
use warnings;

use Data::Dumper;
use above "Genome";
use Command;
use Test::More tests => 147;
use Test::Differences;
use File::Path;


$ENV{UR_DBI_NO_COMMIT} = 1;
$ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;

# Attributes for new model and processing profile
my $model_name = "test_$ENV{USER}";
my $subject_name = 'H_GV-933124G-skin1-9017g';
my $subject_type = 'sample_name';
my %pp_params = (
                 sequencing_platform => 'solexa',
                 indel_finder_name => 'maq0_6_3',
                 dna_type => 'genomic dna',
                 align_dist_threshold => '0',
                 reference_sequence_name => 'refseq-for-test',
                 genotyper_name => 'maq0_6_3',
                 read_aligner_name => 'maq0_6_3',
                 profile_name => 'testing',

                 bare_args => [],
          );

&cleanup_model_links();

#diag('test command create for a processing profile reference alignments');
my $create_pp_command= Genome::Model::Command::Create::ProcessingProfile::ReferenceAlignment->create(%pp_params);

# check and create the processing profile
isa_ok($create_pp_command,'Genome::Model::Command::Create::ProcessingProfile::ReferenceAlignment');

$create_pp_command->dump_status_messages(0);
$create_pp_command->dump_warning_messages(0);
$create_pp_command->dump_error_messages(0);
$create_pp_command->queue_status_messages(1);
$create_pp_command->queue_warning_messages(1);
$create_pp_command->queue_error_messages(1);

ok($create_pp_command->execute(), 'execute processing profile create');     

my @status_messages = $create_pp_command->status_messages();
ok(scalar(@status_messages), 'processing profile create generated a status message');
is($status_messages[0], "created processing profile $pp_params{'profile_name'}");
ok(! scalar($create_pp_command->warning_messages()), 'processing profile create generated no warning messages');
ok(! scalar($create_pp_command->error_messages()), 'processing profile create generated no error messages');


# Get it and make sure there is one
my @processing_profiles = Genome::ProcessingProfile::ReferenceAlignment->get(name => $pp_params{profile_name});
is(scalar(@processing_profiles),1,'expected one processing profile');

# check the type
my $pp = $processing_profiles[0];
isa_ok($pp ,'Genome::ProcessingProfile::ReferenceAlignment');

my $pp_name = delete $pp_params{profile_name};
delete $pp_params{bare_args};

# Test the properties were set and the accessors functionality
for my $property_name (keys %pp_params) {
    is($pp->$property_name,$pp_params{$property_name}, $property_name . ' processing profile accessor');
}

my $create_command = Genome::Model::Command::Create::Model->create(
                                                                   model_name              => $model_name,
                                                                   subject_name            => $subject_name,
                                                                   subject_type            => $subject_type,
                                                                   processing_profile_name => $pp_name,
                                                                   bare_args               => [],
                                                               );
isa_ok($create_command,'Genome::Model::Command::Create::Model');
$create_command->dump_error_messages(0);
$create_command->queue_error_messages(1);
$create_command->dump_warning_messages(0);
$create_command->queue_warning_messages(1);
$create_command->dump_status_messages(0);
$create_command->queue_status_messages(1);

# make a symlink there already so we can detext that executing this will emit a warning message
my $test_model_link_pathname = Genome::Model->model_links_directory . '/' . $model_name;
symlink('/tmp/', $test_model_link_pathname);
my $result = $create_command->execute();
ok($result, 'execute genome-model create');

my @error_messages = $create_command->error_messages();
my @warning_messages = $create_command->warning_messages();
@status_messages = $create_command->status_messages();
ok(! scalar(@error_messages), 'create model generated no error messages');
ok(scalar(@warning_messages), 'create model generated a warning message');
like($warning_messages[0], qr(model symlink.*already exists), 'Warning message complains about the model link already existing');
is($status_messages[0], "created model $model_name", 'status message is correct');
unlink($test_model_link_pathname);


my $genome_model_id = $result->id;

my @models = Genome::Model->get($genome_model_id);
is(scalar(@models),1,'expected one model');

my $model = $models[0];
isa_ok($model,'Genome::Model');

is($model->genome_model_id,$genome_model_id,'model genome_model_id accessor');
is($model->name,$model_name,'model model_name accessor');
is($model->subject_name,$subject_name,'model subject_name accessor');
for my $property_name (keys %pp_params) {
    is($model->$property_name,$pp_params{$property_name},$property_name .' model indirect accessor');
}

# test create for a genome model object
$model_name = 'model_name_here';
$subject_name = 'subject_name_here';
my $obj_create = Genome::Model::Command::Create::Model->create(
                                                               model_name => $model_name,
                                                               subject_name => $subject_name,
                                                               subject_type => $subject_type,
                                                               processing_profile_name   => $pp->name,
                                                               bare_args => [],
                                                           );
isa_ok($obj_create,'Genome::Model::Command::Create::Model');
$obj_create->dump_status_messages(0);  # supress message about creating the model
ok($obj_create->execute,'execute model create');
my $invalid_subject_type_create;
eval {
    $invalid_subject_type_create = Genome::Model::Command::Create::Model->create(
                                                                                    model_name => 'invalid_subject_type_model',
                                                                                    subject_name => 'invalid_subject_type_sample',
                                                                                    subject_type => 'invalid_subject_type',
                                                                                    processing_profile_name   => $pp->name,
                                                                                    bare_args => [],
                                                                                );
};
ok(!defined($invalid_subject_type_create),'expected fail of model create because of invalid subject type');


my $obj = Genome::Model->get(name => $model_name);
ok($obj, 'creation worked');
isa_ok($obj ,'Genome::Model::ReferenceAlignment');

# Test the accessors through the processing profile
#diag('Test accessing model for processing profile properties...');
is($obj->name,$model_name,'name accessor');
is($obj->type_name,'reference alignment','type name accessor');
for my $property_name (keys %pp_params) {
    is($obj->$property_name,$pp_params{$property_name},$property_name .' model indirect accessor');
}

# test the model accessors
#diag('Test accessing model for model properties...');
is($obj->name,$model_name,'model name accessor');
is($obj->subject_name,$subject_name,'subject name accessor');
is($obj->processing_profile_id,$pp->id,'processing profile id accessor');

#diag('subclassing tests - test create for a processing profile object of each subclass');

# Test creation for the corresponding models
#diag('subclassing tests - test create for a genome model object of each subclass');


#reference alignment
test_model_from_params(
                       model_name => 'reference alignment',
                       processing_profile_name => $pp_name,
);

#de novo sanger
test_model_from_params(
                       model_name => 'de novo sanger',
                   );
#imported reference sequence
test_model_from_params(
                       model_name => 'imported reference sequence',
                   );

#watson
test_model_from_params(
                       model_name => 'watson',
                   );
#venter
test_model_from_params(
                       model_name => 'venter',
                   );

#micro array
test_model_from_params(
                       model_name => 'micro array',
                   );

#micro array illumina
test_model_from_params(
                       model_name => 'micro array illumina',
                   );

#micro array affymetrix
test_model_from_params(
                       model_name => 'micro array affymetrix',
                   );

#assembly
test_model_from_params(
                       model_name => 'assembly',
                       subject_name => $subject_name,
                       processing_profile_name => '454_newbler_default_assembly',
                   );

&cleanup_model_links();

exit;

sub delete_model {
    my $model = shift;
    my $archive_file = $model->resolve_archive_file;
    ok($model->delete,'delete model');
    ok(unlink($archive_file),'remove archive file');
}

sub test_model_from_params {
    my %params = @_;

    my @words = split(/ /,$params{model_name});
    my @uc_words = map { ucfirst($_)  } @words;
    my $class = join('',@uc_words);
    $params{bare_args} = [];
    $params{'subject_name'} = 'Bob';
    $params{'subject_type'} = 'sample_name';
    unless ($params{processing_profile_name}) {
        $params{processing_profile_name} = $class;
        my %pp_params = (
                         type_name => $params{model_name},
                         name => $params{processing_profile_name},
                     );
        my $pp = Genome::ProcessingProfile->create(%pp_params);
        isa_ok($pp,'Genome::ProcessingProfile::'. $class);
    }
    my $create_command = Genome::Model::Command::Create::Model->create(%params);
    isa_ok($create_command,'Genome::Model::Command::Create::Model');

    $create_command->dump_error_messages(0);
    $create_command->dump_warning_messages(0);
    $create_command->dump_status_messages(0);
    $create_command->queue_error_messages(1);
    $create_command->queue_warning_messages(1);
    $create_command->queue_status_messages(1);

    ok($create_command->execute, 'create command execution successful');
    my @error_messages = $create_command->error_messages();
    my @warning_messages = $create_command->warning_messages();
    my @status_messages = $create_command->status_messages();
    ok(! scalar(@error_messages), 'no error messages');
    ok(! scalar(@warning_messages), 'no warning messages');
    ok(scalar(@status_messages), 'There was a status message');
    is($status_messages[0], "created model $params{'model_name'}", 'First message is correct');
    # FIXME - some of those have a second message about creating a directory
    # should probably test for that too

    my $model = Genome::Model->get(name => $params{model_name},);
    ok($model, 'creation worked for '. $params{model_name} .' alignment model');
    isa_ok($model,'Genome::Model::'.$class);
    SKIP: {
        skip 'no model to delete', 2 if !$model;
        
        # This would normally emit a warning message about deleting the create command object
        # but in the process of deleting the model it will also delete the command object,
        # leaving us no way to get the warning messages back.  Punt and just ignore them...
        delete_model($model);
    }
}


sub cleanup_model_links {
    my $link_dir = Genome::Model->model_links_directory;
    my @names = map { $link_dir . '/' . $_ }
                    ( "test_$ENV{USER}", # $model_name
                      'model_name_here',
                      'reference alignment',
                      'de novo sanger',
                      'imported reference sequence',
                      'watson',
                      'venter', 
                      'micro array',
                      'micro array illumina',
                      'micro array affymetrix',
                      'assembly',
                   );

    unlink(@names);
}
    
