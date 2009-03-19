#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";

use Test::More tests => 81;

BEGIN {
    use_ok('Genome::Model::InstrumentDataAssignment');
}
my $tmp_dir = File::Temp::tempdir(CLEANUP => 1);

$ENV{GENOME_MODEL_ROOT} = $tmp_dir;

my $mock_id = 0;

############################
# go through all possiblities for creating an invalid instrument data object
# creating some mock objects along the way for use later to create a real instrument data
my $invalid_instrument_data;
eval{
    $invalid_instrument_data = Genome::Model::InstrumentDataAssignment->create();
};
ok(!$invalid_instrument_data,'Failed to create instrument data with no params');

eval {
    $invalid_instrument_data = Genome::Model::InstrumentDataAssignment->create(instrument_data_id => --$mock_id);
};
ok(!$invalid_instrument_data,'Failed to create instrument data with no model_id');

eval {
    $invalid_instrument_data = Genome::Model::InstrumentDataAssignment->create(model_id => --$mock_id);
};
ok(!$invalid_instrument_data,'Failed to create instrument data with no instrument_data_id');

$invalid_instrument_data = Genome::Model::InstrumentDataAssignment->create(
                                                   model_id => --$mock_id,
                                                   instrument_data_id => --$mock_id,
                                               );
isa_ok($invalid_instrument_data,'Genome::Model::InstrumentDataAssignment');
my @invalid_tags = $invalid_instrument_data->invalid;
is(scalar(@invalid_tags),2,'Invalid instrument data with no model or run chunk objects');
eval {
    $invalid_instrument_data->read_length;
};
ok(scalar(grep {$_ =~ /^no instrument data for id/ } $@),'read_length failed because no run chunk found');


my $mock_instrument_data = Genome::InstrumentData::Solexa->create_mock(
                                                                 id => --$mock_id,
                                                                 instrument_data_id => $mock_id,
                                                                 sample_name => 'test_sample_name',
                                                                 run_name => 'test_run_name',
                                                                 subset_name => 'test_subset_name',
                                                                 sequencing_platform => 'solexa',
                                                       );
$mock_instrument_data->set_list('allocations');
$mock_instrument_data->set_always('calculate_alignment_estimated_kb_usage',undef);
$mock_instrument_data->mock('resolve_alignment_path_for_aligner_and_refseq',
                            \&Genome::InstrumentData::resolve_alignment_path_for_aligner_and_refseq);
$mock_instrument_data->mock('alignment_allocation_for_aligner_and_refseq',
                            \&Genome::InstrumentData::alignment_allocation_for_aligner_and_refseq);
$mock_instrument_data->mock('alignment_directory_for_aligner_and_refseq',
                            \&Genome::InstrumentData::alignment_directory_for_aligner_and_refseq);

$invalid_instrument_data = Genome::Model::InstrumentDataAssignment->create(
                                                   model_id => --$mock_id,
                                                   instrument_data_id => $mock_instrument_data->id,
                                               );
isa_ok($invalid_instrument_data,'Genome::Model::InstrumentDataAssignment');
@invalid_tags = $invalid_instrument_data->invalid;
is(scalar(@invalid_tags),1,'Invalid instrument data with no model object');


my $mock_pp = Genome::ProcessingProfile::ReferenceAlignment::Solexa->create_mock(
                                                                                 id => --$mock_id,
                                                                             );
my $mock_model = Genome::Model::ReferenceAlignment->create_mock(
                                                                id => --$mock_id,
                                                                genome_model_id => $mock_id,
                                                                subject_name => 'test_sample_name',
                                                                subject_type => 'test_subject_type',
                                                                processing_profile_id => $mock_pp->id,
                                                                name => 'test_model_name',
                                                                read_aligner_name => 'test_read_aligner_name',
                                                                reference_sequence_name => 'test_reference_sequence_name',
                                                            );

$invalid_instrument_data = Genome::Model::InstrumentDataAssignment->create(
                                                   model_id => $mock_model->id,
                                                   instrument_data_id => --$mock_id,
                                               );
isa_ok($invalid_instrument_data,'Genome::Model::InstrumentDataAssignment');
@invalid_tags = $invalid_instrument_data->invalid;
is(scalar(@invalid_tags),1,'Invalid instrument data with no run chunk object');

###############################
# create a real instrument data using the mock objects
my $new_instrument_data = Genome::Model::InstrumentDataAssignment->create(
                                                  instrument_data_id => $mock_instrument_data->id,
                                                  model_id => $mock_model->id,
                                              );
isa_ok($new_instrument_data,'Genome::Model::InstrumentDataAssignment');

my $expected_alignment_directory = $tmp_dir .'/alignment_links/'. $mock_model->read_aligner_name .'/'. $mock_model->reference_sequence_name .'/'.
    $mock_instrument_data->run_name .'/'. $mock_instrument_data->subset_name .'_'. $mock_instrument_data->id;
is($new_instrument_data->alignment_directory(check_only => 1),$expected_alignment_directory,
   'got expected instrument_data_alignment_directory: '. $expected_alignment_directory);

###############################
#Test file accessors before creating directory
ok(!defined($new_instrument_data->alignment_file_paths),'alignment_file_paths returns undef');
ok(!defined($new_instrument_data->aligner_output_file_paths),'aligner_output_file_paths returns undef');
ok(!defined($new_instrument_data->poorly_aligned_reads_list_paths),'poorly_aligned_reads_list_paths returns undef');
ok(!defined($new_instrument_data->poorly_aligned_reads_fastq_paths),'poorly_aligned_reads_fastq_paths returns undef');
ok(!defined($new_instrument_data->contaminants_file_path),'contaminants_file_path returns undef');

# TODO: trap error messages and parse 
ok(!defined($new_instrument_data->alignment_files_for_refseq),'no ref_seq_id passed to alignment_files_for_refseq');
ok(!defined($new_instrument_data->alignment_files_for_refseq('test_ref_seq_id')),'alignment_directory does not exist');
ok(!defined($new_instrument_data->get_alignment_statistics),'no aligner output file found for get_alignment_statistics');

###############################
#create_directory and test again with no files
ok(Genome::Utility::FileSystem->create_directory($expected_alignment_directory),'alignment_directory created');
is($new_instrument_data->alignment_file_paths,0,'alignment_file_paths returns no file paths');
is($new_instrument_data->aligner_output_file_paths,0,'aligner_output_file_paths returns no file paths');
is($new_instrument_data->poorly_aligned_reads_list_paths,0,'poorly_aligned_reads_list_paths returns no file paths');
is($new_instrument_data->poorly_aligned_reads_fastq_paths,0,'poorly_aligned_reads_fastq_paths returns no file paths');
is($new_instrument_data->contaminants_file_path,0,'contaminants_file_path returns no file path');
is($new_instrument_data->alignment_files_for_refseq('test_ref_seq_id'),0,'instrument_data_alignment_files_for_refseq returns no file paths');

###############################
# Test methods that use indirect accessor on the run chunk object to calculate return values
$mock_instrument_data->mock('read_length', sub { return -1; } );
eval {
    $new_instrument_data->read_length;
};
ok(scalar(grep {$_ =~ /^Impossible value/} $@),'impossible value found for read length');
my $expected_read_length = 50;
$mock_instrument_data->mock('read_length', sub { return $expected_read_length; } );
is($new_instrument_data->read_length,$expected_read_length,'got expected read length: '. $expected_read_length);

my $expected_read_count = 1234567;
$mock_instrument_data->set_always('_calculate_total_read_count',$expected_read_count);
is($new_instrument_data->_calculate_total_read_count,$expected_read_count,'got expected read_count: '. $expected_read_count);

################################
# TODO: Add test if the run chunk is external, this requires a fake fastq file to parse



# TODO:
# copy real alignment files to the instrument_data_alignment_directory so accessors work correctly
# currently this is tested below using real data


ok($new_instrument_data->yaml_string,'got a yaml string');
ok($new_instrument_data->delete,'deleted test instrument data');




##################################################
# below tests rely on real run chunks and models #
##################################################
$ENV{GENOME_MODEL_ROOT} = undef;



ok(my $instrument_data = Genome::Model::InstrumentDataAssignment->get(instrument_data_id=> 2499312867, model_id=>2721044485), "Got a instrument_data");
isa_ok($instrument_data, "Genome::Model::InstrumentDataAssignment");

ok(my $alignment_directory = $instrument_data->alignment_directory, 'Got the alignment_directory');
ok(-d $alignment_directory, 'alignment_directory'. $alignment_directory .' exists');

ok(scalar($instrument_data->invalid) == 0, "Checked invalid, seems valid");

ok(my @alignment_file_paths = $instrument_data->alignment_file_paths, "Got the alignment_file_paths");
for my $file_path (@alignment_file_paths) {
    ok (-e $file_path, "file path $file_path exists");
}

ok(my @aligner_output_file_paths = $instrument_data->aligner_output_file_paths, "Got the aligner_output_file_paths");
for my $file_path (@aligner_output_file_paths) {
    ok (-e $file_path, "file path $file_path exists");
}

ok(my @poorly_aligned_reads_list_paths = $instrument_data->poorly_aligned_reads_list_paths, "Got the poorly_aligned_reads_list_paths");
for my $file_path (@poorly_aligned_reads_list_paths) {
    ok (-e $file_path, "file path $file_path exists");
}

ok(my @poorly_aligned_reads_fastq_paths = $instrument_data->poorly_aligned_reads_fastq_paths, "Got the poorly_aligned_reads_fastq_paths");
for my $file_path (@poorly_aligned_reads_fastq_paths) {
    ok (-e $file_path, "file path $file_path exists");
}

SKIP: {
          skip "Not sure this is supposed to work for solexa", 1;
          ok(my @contaminants_file_path = $instrument_data->contaminants_file_path, "Got the contaminants_file_path");
          for my $file_path (@contaminants_file_path) {
              ok (-e $file_path, "file path $file_path exists");
          }
}

ok(my $read_length = $instrument_data->read_length, "Got the read length");
ok(my $total_read_count = $instrument_data->_calculate_total_read_count, "Got total read count");

ok(my @instrument_data_alignment_files_for_refseq = $instrument_data->alignment_files_for_refseq("22"), "Got the alignment_files_for_refseq");
for my $file_path (@instrument_data_alignment_files_for_refseq) {
    ok (-e $file_path, "file path $file_path exists");
}

ok(my $yaml_string = $instrument_data->yaml_string, "Got the yaml string");

ok(my $alignment_statistics = $instrument_data->get_alignment_statistics, "Got the alignment statistics");
ok($alignment_statistics->{total}, "alignment statistics has a total");
ok($alignment_statistics->{isPE}, "alignment statistics has a isPE");
ok($alignment_statistics->{mapped}, "alignment statistics has a mapped");
ok($alignment_statistics->{paired}, "alignment statistics has a paired");




