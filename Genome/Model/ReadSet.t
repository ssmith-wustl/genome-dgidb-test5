#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";

use Test::More tests => 83;

BEGIN {
    use_ok('Genome::Model::ReadSet');
}

my $tmp_dir = File::Temp::tempdir(CLEANUP => 1);
my $mock_id = 0;

############################
# go through all possiblities for creating an invalid read set object
# creating some mock objects along the way for use later to create a real read set
my $invalid_read_set;
eval{
    $invalid_read_set = Genome::Model::ReadSet->create();
};
ok(!$invalid_read_set,'Failed to create read set with no params');

eval {
    $invalid_read_set = Genome::Model::ReadSet->create(read_set_id => --$mock_id);
};
ok(!$invalid_read_set,'Failed to create read set with no model_id');

eval {
    $invalid_read_set = Genome::Model::ReadSet->create(model_id => --$mock_id);
};
ok(!$invalid_read_set,'Failed to create read set with no read_set_id');

$invalid_read_set = Genome::Model::ReadSet->create(
                                                   model_id => --$mock_id,
                                                   read_set_id => --$mock_id,
                                               );
isa_ok($invalid_read_set,'Genome::Model::ReadSet');
my @invalid_tags = $invalid_read_set->invalid;
is(scalar(@invalid_tags),2,'Invalid read set with no model or run chunk objects');
eval {
    $invalid_read_set->read_length;
};
ok(scalar(grep {$_ =~ /^no read set for id/ } $@),'read_length failed because no run chunk found');


my $mock_run_chunk = Genome::RunChunk::Solexa->create_mock(
                                                           id => --$mock_id,
                                                           genome_model_run_id => $mock_id,
                                                           sample_name => 'test_sample_name',
                                                           run_name => 'test_run_name',
                                                           subset_name => 'test_subset_name',
                                                           sequencing_platform => 'solexa',
                                                       );
$invalid_read_set = Genome::Model::ReadSet->create(
                                                   model_id => --$mock_id,
                                                   read_set_id => $mock_run_chunk->id,
                                               );
isa_ok($invalid_read_set,'Genome::Model::ReadSet');
@invalid_tags = $invalid_read_set->invalid;
is(scalar(@invalid_tags),1,'Invalid read set with no model object');


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
                                                            );
$mock_model->set_always('alignment_directory',$tmp_dir);

$invalid_read_set = Genome::Model::ReadSet->create(
                                                   model_id => $mock_model->id,
                                                   read_set_id => --$mock_id,
                                               );
isa_ok($invalid_read_set,'Genome::Model::ReadSet');
@invalid_tags = $invalid_read_set->invalid;
is(scalar(@invalid_tags),1,'Invalid read set with no run chunk object');

###############################
# create a real read set using the mock objects
my $new_read_set = Genome::Model::ReadSet->create(
                                                  read_set_id => $mock_run_chunk->id,
                                                  model_id => $mock_model->id,
                                              );
isa_ok($new_read_set,'Genome::Model::ReadSet');

is($new_read_set->alignment_directory,$tmp_dir,'got expected alignment directory: '. $tmp_dir);

my $expected_read_set_alignment_directory = $tmp_dir .'/'.
    $mock_run_chunk->run_name .'/'. $mock_run_chunk->subset_name .'_'. $mock_run_chunk->id;
is($new_read_set->read_set_alignment_directory,$expected_read_set_alignment_directory,
   'got expected read_set_alignment_directory: '. $expected_read_set_alignment_directory);

###############################
#Test file accessors before creating directory
ok(!defined($new_read_set->alignment_file_paths),'alignment_file_paths returns undef');
ok(!defined($new_read_set->aligner_output_file_paths),'aligner_output_file_paths returns undef');
ok(!defined($new_read_set->poorly_aligned_reads_list_paths),'poorly_aligned_reads_list_paths returns undef');
ok(!defined($new_read_set->poorly_aligned_reads_fastq_paths),'poorly_aligned_reads_fastq_paths returns undef');
ok(!defined($new_read_set->contaminants_file_path),'contaminants_file_path returns undef');

# TODO: trap error messages and parse 
ok(!defined($new_read_set->read_set_alignment_files_for_refseq),'no ref_seq_id passed to read_set_alignment_files_for_refseq');
ok(!defined($new_read_set->read_set_alignment_files_for_refseq('test_ref_seq_id')),'read_set_alignment_directory does not exist');
ok(!defined($new_read_set->get_alignment_statistics),'no aligner output file found for get_alignment_statistics');

###############################
#create_directory and test again with no files
ok(Genome::Utility::FileSystem->create_directory($expected_read_set_alignment_directory),'read_set_alignment_directory created');
is($new_read_set->alignment_file_paths,0,'alignment_file_paths returns no file paths');
is($new_read_set->aligner_output_file_paths,0,'aligner_output_file_paths returns no file paths');
is($new_read_set->poorly_aligned_reads_list_paths,0,'poorly_aligned_reads_list_paths returns no file paths');
is($new_read_set->poorly_aligned_reads_fastq_paths,0,'poorly_aligned_reads_fastq_paths returns no file paths');
is($new_read_set->contaminants_file_path,0,'contaminants_file_path returns no file path');
is($new_read_set->read_set_alignment_files_for_refseq('test_ref_seq_id'),0,'read_set_alignment_files_for_refseq returns no file paths');

###############################
# Test methods that use indirect accessor on the run chunk object to calculate return values
$mock_run_chunk->mock('read_length', sub { return -1; } );
eval {
    $new_read_set->read_length;
};
ok(scalar(grep {$_ =~ /^Impossible value for read_length field/} $@),'impossible value found for read length');
my $expected_read_length = 50;
$mock_run_chunk->mock('read_length', sub { return $expected_read_length; } );
is($new_read_set->read_length,$expected_read_length,'got expected read length: '. $expected_read_length);

$mock_run_chunk->mock('clusters', sub { return -1; } );
eval {
    $new_read_set->_calculate_total_read_count;
};
ok(scalar(grep {$_ =~ /^Impossible value for clusters field/} $@),'impossible value found for clusters');
my $expected_clusters = 1234567;
$mock_run_chunk->mock('clusters', sub { return $expected_clusters; } );
is($new_read_set->_calculate_total_read_count,$expected_clusters,'got expected clusters: '. $expected_clusters);

################################
# TODO: Add test if the run chunk is external, this requires a fake fastq file to parse



# TODO:
# copy real alignment files to the read_set_alignment_directory so accessors work correctly
# currently this is tested below using real data


ok($new_read_set->yaml_string,'got a yaml string');
ok($new_read_set->delete,'deleted test read set');

##################################################
# below tests rely on real run chunks and models #
##################################################

ok(my $read_set = Genome::Model::ReadSet->get(read_set_id=> 2499312867, model_id=>2721044485), "Got a read_set");
isa_ok($read_set, "Genome::Model::ReadSet");

ok(my $read_set_alignment_directory = $read_set->read_set_alignment_directory, "Got the read_set_alignment_directory");
ok(-d $read_set_alignment_directory, "read_set_alignment_directory exists");

ok(scalar($read_set->invalid) == 0, "Checked invalid, seems valid");

ok(my @alignment_file_paths = $read_set->alignment_file_paths, "Got the alignment_file_paths");
for my $file_path (@alignment_file_paths) {
    ok (-e $file_path, "file path $file_path exists");
}

ok(my @aligner_output_file_paths = $read_set->aligner_output_file_paths, "Got the aligner_output_file_paths");
for my $file_path (@aligner_output_file_paths) {
    ok (-e $file_path, "file path $file_path exists");
}

ok(my @poorly_aligned_reads_list_paths = $read_set->poorly_aligned_reads_list_paths, "Got the poorly_aligned_reads_list_paths");
for my $file_path (@poorly_aligned_reads_list_paths) {
    ok (-e $file_path, "file path $file_path exists");
}

ok(my @poorly_aligned_reads_fastq_paths = $read_set->poorly_aligned_reads_fastq_paths, "Got the poorly_aligned_reads_fastq_paths");
for my $file_path (@poorly_aligned_reads_fastq_paths) {
    ok (-e $file_path, "file path $file_path exists");
}

SKIP: {
          skip "Not sure this is supposed to work for solexa", 1;
          ok(my @contaminants_file_path = $read_set->contaminants_file_path, "Got the contaminants_file_path");
          for my $file_path (@contaminants_file_path) {
              ok (-e $file_path, "file path $file_path exists");
          }
}

ok(my $read_length = $read_set->read_length, "Got the read length");
ok(my $total_read_count = $read_set->_calculate_total_read_count, "Got total read count");

ok(my @read_set_alignment_files_for_refseq = $read_set->read_set_alignment_files_for_refseq("22"), "Got the read_set_alignment_files_for_refseq");
for my $file_path (@read_set_alignment_files_for_refseq) {
    ok (-e $file_path, "file path $file_path exists");
}

ok(my $yaml_string = $read_set->yaml_string, "Got the yaml string");

ok(my $alignment_statistics = $read_set->get_alignment_statistics, "Got the alignment statistics");
ok($alignment_statistics->{total}, "alignment statistics has a total");
ok($alignment_statistics->{isPE}, "alignment statistics has a isPE");
ok($alignment_statistics->{mapped}, "alignment statistics has a mapped");
ok($alignment_statistics->{paired}, "alignment statistics has a paired");




