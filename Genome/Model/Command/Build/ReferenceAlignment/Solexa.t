#!/gsc/bin/perl


###############################################
# Solexa Reference Alignment Integration Test #
###############################################

use strict;
use warnings;

use Test::More;

use above 'Genome';
use Genome::Model::Command::Build::ReferenceAlignment::Test;

use GSCApp;
App::DB->db_access_level('rw');
App::DB::TableRow->use_dummy_autogenerated_ids(1);
App::DBI->no_commit(1);
App->init;

$ENV{UR_DBI_NO_COMMIT} = 1;

# NOTE: run from 32-bit first to compile correct inline libraries
# Then this should run from 64-bit to actually execute.
my $archos = `uname -a`;
if ($archos !~ /64/) {
    plan skip_all => "Must run from 64-bit machine";
}
my $auto_execute = 0;
if ($auto_execute) {
    plan tests => 75;
} else {
    #plan tests => 416;
    plan tests => 399;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}
my $tmp_dir = File::Temp::tempdir('TestAlignmentDataXXXXX', DIR => '/gsc/var/cache/testsuite/running_testsuites', CLEANUP => 1);
my $data_dir = '/gsc/var/cache/testsuite/data/Genome-Model-Solexa-Integration-Test-2';
my $message_flag = 1;  #set this to 1 to turn on verbose message output
my $model_name = "test_solexa_$ENV{USER}";
my $processing_profile_name = "test_solexa_pp_$ENV{USER}";
my $subject_name = 'H_GV-933124G-skin1-9017g';
my $subject_type = 'sample_name';
my @instrument_data = setup_test_data($subject_name);

my $build_test = Genome::Model::Command::Build::ReferenceAlignment::Test->new(
    model_name => $model_name,
    subject_name => $subject_name,
    subject_type => $subject_type,
    processing_profile_name => $processing_profile_name,
    auto_execute => $auto_execute,
    instrument_data => \@instrument_data,
    data_dir => $data_dir,
    messages => $message_flag,
);
isa_ok($build_test,'Genome::Model::Command::Build::ReferenceAlignment::Test');

$build_test->create_test_pp(
    sequencing_platform => 'solexa',
    name => $processing_profile_name,
    dna_type => 'genomic dna',
    align_dist_threshold => '0',
    multi_read_fragment_strategy => 'eliminate start site duplicates',
    indel_finder_name => 'maq0_7_1',
    genotyper_name => 'maq0_7_1',
    read_aligner_name => 'maq0_7_1',
    reference_sequence_name => 'refseq-for-test',
    #filter_ruleset_name => 'basic',
);
$build_test->runtests;

exit;

sub setup_test_data {
    my $subject_name = shift;
    my @instrument_data;
    my @run_dirs = grep { -d $_ } glob("$data_dir/*_*-*_*_*");
    my $mock_id = -10;
    my $library = 'TESTINGLIBRARY'; 
    for my $run_dir (@run_dirs) {
        my $run_dir_params = GSC::PSE::SolexaSequencing::SolexaRunDirectory->parse_regular_run_directory($run_dir);
        my $read_length = int($$run_dir_params{'run_id'});
        my $paired_end = 0;
        if ($$run_dir_params{'flow_cell_id'} eq '30LN0') {
            $paired_end = 1;
	    $library = "TESTINGLIBRARY_PAIRED";	
        }
        for my $lane (1 .. 8) {
            my $instrument_data = Genome::InstrumentData::Solexa->create_mock(
                                                                              id => UR::DataSource->next_dummy_autogenerated_id,
                                                                              gerald_directory => $run_dir,
                                                                              sequencing_platform => 'solexa',
                                                                              sample_name => $subject_name,
                                                                              subset_name => $lane,
                                                                              run_name => $$run_dir_params{'run_name'},
                                                                              full_path => undef,
                                                                              is_paired_end => $paired_end,
                                                                              clusters => 100,
                                                                              is_external => 0,
                                                                              read_length => $read_length,
                							      library_name => $library,
                                                                          );
            $instrument_data->mock('find_or_generate_alignments_dir',
                                   \&Genome::InstrumentData::find_or_generate_alignments_dir);
            #$instrument_data->mock('alignment_directory_for_aligner_and_refseq',
            #                       \&Genome::InstrumentData::alignment_directory_for_aligner_and_refseq);
            $instrument_data->set_always('alignment_directory_for_aligner_and_refseq',
                                         $tmp_dir .'/test_alignment_data/'. $instrument_data->subset_name .'_'. $instrument_data->id);
            $instrument_data->mock('bfq_filenames',
                                   \&Genome::InstrumentData::Solexa::bfq_filenames);
            $instrument_data->mock('resolve_bfq_filenames',
                                   \&Genome::InstrumentData::Solexa::resolve_bfq_filenames);
            $instrument_data->mock('_calculate_total_read_count',
                                   \&Genome::InstrumentData::Solexa::_calculate_total_read_count);
            push @instrument_data, $instrument_data;

        }
	#} #lib loop
    }
    return @instrument_data;
}

1;
