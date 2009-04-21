#!/usr/bin/env perl

###############################################
# Solexa Reference Alignment Integration Test #
###############################################

use strict;
use warnings;

our $override_testdir;
BEGIN {
    $override_testdir = pop(@ARGV);
    if ($override_testdir) {
        unless ($override_testdir =~ /^\//) {
            $override_testdir = '/gsc/var/cache/testsuite/data/' . $override_testdir;
        }
        warn "\n!!!!!!!!!!!!!!!!! using test directory override $override_testdir !!!!!!!!!!!!!!!\n";
    }
}

use Test::More;

use above 'Genome';
use Genome::Model::Command::Build::ReferenceAlignment::Test;
$ENV{UR_DBI_NO_COMMIT} = 1;

use GSCApp;
App::DB->db_access_level('rw');
App::DB::TableRow->use_dummy_autogenerated_ids(1);
App::DBI->no_commit(1);

# This _should_ not be needed anywhere
#App->init;

# NOTE: run from 32-bit first to compile correct inline libraries
# Then this should run from 64-bit to actually execute.
my $archos = `uname -a`;
if ($archos !~ /64/) {
    plan skip_all => "Must run from 64-bit machine";
}
my $auto_execute = 0;
if ($auto_execute) {
    plan tests => 76;
} else {
    #plan tests => 416;
    plan tests => 253;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

my $tmp_dir;
if ($override_testdir) {
    $tmp_dir = $override_testdir;
}
else {
    $tmp_dir = File::Temp::tempdir('TestAlignmentDataXXXXX', DIR => '/gsc/var/cache/testsuite/running_testsuites', CLEANUP => 1);
}


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
    genotyper_version => '0.7.1',
    read_aligner_name => 'maq',
    read_aligner_version => '0.7.1',
    reference_sequence_name => 'refseq-for-test',
    #filter_ruleset_name => 'basic',
);
$build_test->runtests;

my $comparison_dir = '/gsc/var/cache/testsuite/data/'
        . 'Genome-Model-Command-Build-ReferenceAlignment-Solexa/'
        . 'alignment-root-expected-v2';

my @diff = `diff -r --brief $tmp_dir $comparison_dir`; 
my @bad;
for my $diff (@diff) {
    unless ($diff =~ /Files (.*aligner_output) and (.*aligner_output) differ/) {
        push @bad, $diff;
    }
}

# NOTE: when we intentially change the content of the alignment directory,
# this test case will break.  The solution is to make a new directory with a different version
# number, and switch the test case to use it.  That means that old svn snapshots will still run vs
# the old data and pass.  This is our only means of tracking the essentials of an alignment directory.
is(scalar(@bad),0, "count of significant differences with the expected directory content is zero")
    or do {
        diag(join("\n",@bad)); 
        diag("leaving a copy of the test alignment dir in the pwd.  compare to $comparison_dir");
        my $rv = Genome::Utility::FileSystem->copy_directory($tmp_dir, $0 . '.last_failure');
    };

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
        my @quality_converters  = ('sol2sanger', 'sol2phred');
        for my $lane (1 .. 8) {
            my $instrument_data = Genome::InstrumentData::Solexa->create_mock(
                                                                              #id => UR::DataSource->next_dummy_autogenerated_id,
                                                                              id => $mock_id--,
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
            my $allocation_path = sprintf('alignment_data/%s/%s/%s/%s_%s',
                                          'maq0_7_1',
                                          'refseq-for-test',
                                          $instrument_data->run_name,
                                          $instrument_data->subset_name,
                                          $instrument_data->id,    );
            #my $allocator_id = UR::DataSource->next_dummy_autogenerated_id;
            my $allocator_id = $mock_id--;
	    my $alignment_allocation = Genome::Disk::Allocation->create_mock(
                                                                             id => $allocator_id,
                                                                             disk_group_name => 'info_apipe',
                                                                             allocation_path => $allocation_path,
                                                                             mount_path => $tmp_dir,
                                                                             group_subdirectory => '',
                                                                             kilobytes_requested => 10000,
                                                                             kilobytes_used => 0,
                                                                             allocator_id => $allocator_id,
                                                                             owner_class_name => 'Genome::InstrumentData::Solexa',
                                                                             owner_id => $instrument_data->id,
                                                                         );
            $alignment_allocation->mock('reallocate',sub { return 1; });
            $alignment_allocation->mock('deallocate',sub { return 1; });
            $alignment_allocation->set_always('absolute_path',$tmp_dir.'/'.$allocation_path);
            $instrument_data->set_list('allocations',$alignment_allocation);
            $instrument_data->set_always('sample_type','dna');

            my $index = $lane % 2;
            $instrument_data->set_always('resolve_quality_converter',$quality_converters[$index]);

            $instrument_data->set_always('dump_illumina_fastq_archive',$run_dir);
            push @instrument_data, $instrument_data;

        }
	#} #lib loop
    }
    return @instrument_data;
}

1;
