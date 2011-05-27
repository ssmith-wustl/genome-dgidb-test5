#!/usr/bin/env perl

use strict;
use warnings;
use Carp;
use File::Temp;
use File::Basename;
use Test::More;
use Cwd;

plan skip_all => 'broken with new API';

use above 'Genome';
use Genome::Model::Event::Build::ReferenceAlignment::Test;

$ENV{UR_DBI_NO_COMMIT} = 1;
$ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;

my $archos = `uname -a`;
if ($archos !~ /64/) {
    plan skip_all => "Must run from 64-bit machine";
}

#plan skip_all => 'this test is hanging presumambly from a workflow related issue';
plan tests => 44;

my $message_flag = 0;


my $tmp_dir = File::Temp::tempdir('TestAlignmentResultXXXXX', DIR => '/gsc/var/cache/testsuite/running_testsuites', CLEANUP => 1);
my $model_name = "test_454_" . Genome::Sys->username;
my $subject_name = 'TCAM-090304_gDNA_tube1';
my $subject_type = 'sample_name';
my $pp_name = '454_ReferenceAlignment_test';
my %pp_params = (
                 name => $pp_name,
                 dna_type => 'genomic dna',
                 indel_finder_name => 'varScan',
                 read_aligner_name => 'blat',
                 reference_sequence_name => 'refseq-for-test',
                 sequencing_platform => '454',
             );

my @instrument_data = setup_test_data($subject_name);
#GSC::RunRegion454->get(sample_name => $subject_name);
my $build_test = Genome::Model::Event::Build::ReferenceAlignment::Test->new(
                                                                                  model_name => $model_name,
                                                                                  subject_name => $subject_name,
                                                                                  subject_type => $subject_type,
                                                                                  processing_profile_name => $pp_name,
                                                                                  instrument_data => \@instrument_data,
                                                                                  tmp_dir => $tmp_dir,
                                                                                  messages => $message_flag,
                                                                              );
isa_ok($build_test,'Genome::Model::Event::Build::ReferenceAlignment::Test');
$build_test->create_test_pp(%pp_params);
$build_test->runtests;
exit;


sub setup_test_data {
    my $subject_name = shift;
    my @instrument_data;
    
    my $cwd = getcwd;

    chdir $tmp_dir || die("Failed to change directory to '$tmp_dir'");

    my $zip_file = '/gsc/var/cache/testsuite/data/Genome-Model-Command-AddReads/addreads-454-varScan.tgz';
    `tar -xzf $zip_file`;

    my @run_dirs = grep { -d $_ } glob("$tmp_dir/R_2008_07_29_*");
    for my $run_dir (@run_dirs) {
        my $run_name = basename($run_dir);
        my $analysis_name = $run_name . Genome::Sys->username . $$;
        $analysis_name =~ s/^R/D/;
        my @files = grep { -e $_ } glob("$run_dir/*.sff");
        for my $file (@files) {
            $file =~ /(\d+)\.sff/;
            my $region_number = $1;
            my $rr454 = GSC::RunRegion454->create(
                                                  analysis_name   => $analysis_name,
                                                  incoming_dna_name => $subject_name,
                                                  region_number  => $region_number,
                                                  run_name       => $run_name,
                                                  sample_name    => $subject_name,
                                                  total_key_pass => -1,
                                                  total_raw_wells => -1,
                                                  copies_per_bead => -1,
                                                  key_pass_wells => -1,
                                                  library_name => 'TESTINGLIBRARY',
                                                  #region_id => -1,
                                                  fc_id => -2040001,
                                              );
            my $sff454 = GSC::AnalysisSFF454->create_from_sff_file(
                                                                   region_id => $rr454->region_id,
                                                                   sff_file => $file,
                                                               );
            #push @read_sets, $rr454;
            my $instrument_data = Genome::InstrumentData::454->create_mock(
                                                                           id => $rr454->region_id,
                                                                           sequencing_platform => '454',
                                                                           sample_name => $rr454->sample_name,
                                                                           run_name => $rr454->run_name,
                                                                           subset_name => $rr454->region_number,
                                                                       );
            $instrument_data->set_always('class', 'Genome::InstrumentData::454');
            $instrument_data->mock('__meta__', \&Genome::InstrumentData::454::__meta__);
            unless ($instrument_data) {
                die ('Failed to create instrument data object for '. $rr454->run_name);
            }
my $allocation_path = sprintf('alignment_data/%s/%s/%s/%s_%s',
                              'blat',
                              'refseq-for-test',
                              $instrument_data->run_name,
                              $instrument_data->subset_name,
                              $instrument_data->id,    );
            my $id = UR::DataSource->next_dummy_autogenerated_id;
            my $alignment_allocation = Genome::Disk::Allocation->create_mock(
                                                                             disk_group_name => 'info_apipe',
                                                                             allocation_path => $allocation_path,
                                                                             mount_path => $tmp_dir,
                                                                             group_subdirectory => '',
                                                                             kilobytes_requested => 10000,
                                                                             kilobytes_used => 0,
                                                                             id => $id,
                                                                             owner_class_name => 'Genome::InstrumentData::454',
                                                                             owner_id => $instrument_data->id,
                                                                         );
            $alignment_allocation->mock('reallocate',sub { return 1; });
            $alignment_allocation->mock('deallocate',sub { return 1; });
            $alignment_allocation->set_always('absolute_path',$tmp_dir.'/'.$allocation_path);
            $instrument_data->set_list('allocations',$alignment_allocation);
            $instrument_data->set_always('sample_type','dna');

            $instrument_data->mock('full_path',sub {
                                       my $self = shift;
                                       if (@_) {
                                           $self->{_full_path} = shift;
                                       }
                                       return $self->{_full_path};
                                   }
                               );
            # TODO:switch these paths to something like /gsc/var/cache/testsuite/data/BLAH
            #$instrument_data->mock('_data_base_path',\&Genome::InstrumentData::_data_base_path);
            #$instrument_data->mock('_default_full_path',\&Genome::InstrumentData::_default_full_path);
            #$instrument_data->set_always('resolve_full_path',$run_dir);
            #$instrument_data->mock('resolve_sff_path',\&Genome::InstrumentData::454::resolve_sff_path);
            $instrument_data->set_always('is_external',undef);
            $instrument_data->set_always('sff_file',$run_dir .'/'.$region_number .'.sff');
            $instrument_data->set_always('fasta_file',$run_dir .'/'.$region_number .'.fa');
            $instrument_data->set_always('qual_file',$run_dir .'/'.$region_number .'.qual');
            $instrument_data->set_always('dump_to_file_system',1);
            push @instrument_data, $instrument_data;
        }
    }
    chdir $cwd || die("Failed to change directory to '$cwd'");
    return @instrument_data;
}

exit 0;

