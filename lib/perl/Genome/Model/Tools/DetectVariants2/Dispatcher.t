#!/usr/bin/env perl

use strict;
use warnings;

BEGIN {
    $ENV{UR_DBI_NO_COMMIT}=1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS}=1;
    $ENV{NO_LSF}=1;
}

use Parse::RecDescent qw/RD_ERRORS RD_WARN RD_TRACE/;
use Data::Dumper;
use Test::More tests => 6;
use above 'Genome';
use Genome::SoftwareResult;

# Override lock name because if people cancel tests locks don't get cleaned up.
*Genome::SoftwareResult::_resolve_lock_name = sub {
    return Genome::Sys->create_temp_file_path;
};


#Parsing tests
my $det_class_base = 'Genome::Model::Tools::DetectVariants2';
my $dispatcher_class = "${det_class_base}::Dispatcher";
my $refbuild_id = 101947881;
use_ok($dispatcher_class);

# hash of strings => expected output hash

my $obj = $dispatcher_class->create(
    snv_detection_strategy => 'samtools r599 [-p 1] intersect samtools r613 [-p 2]',
    indel_detection_strategy => 'samtools r963 [-p 1]',
    sv_detection_strategy => 'breakdancer 2010_06_24 [-p 3]',
    );

my $expected_plan = {
    'breakdancer' => {
        '2010_06_24' => {
            'sv' => [
                {
                    'params' => '-p 3',
                    'version' => '2010_06_24',
                    'name' => 'breakdancer',
                    'filters' => [],
                    'class' => 'Genome::Model::Tools::DetectVariants2::Breakdancer'
                }
            ]
        }
    },
    'samtools' => {
        'r599' => { 
            'indel' => [
                {
                    'params' => '-p 1',
                    'version' => 'r599', 
                    'name' => 'samtools',
                    'filters' => [],
                    'class' => 'Genome::Model::Tools::DetectVariants2::Samtools'
                }
            ],
            'snv' => [
                {
                    'params' => '-p 1',
                    'version' => 'r963',
                    'name' => 'samtools',
                    'filters' => [],
                    'class' => 'Genome::Model::Tools::DetectVariants2::Samtools'
                }
            ]
        },
        'r613' => { #r613
            'snv' => [
                {
                    'params' => '-p 2',
                    'version' => 'r613', #613
                    'name' => 'samtools',
                    'filters' => [],
                    'class' => 'Genome::Model::Tools::DetectVariants2::Samtools',
                }
            ]
        }
    }
};

my ($trees, $plan) = $obj->plan;
is_deeply($plan, $expected_plan, "plan matches expectations");

my $ref_seq_build = Genome::Model::Build::ImportedReferenceSequence->get(type_name => 'imported reference sequence', name => 'NCBI-human-build36');
ok($ref_seq_build, 'Got a reference sequence build') or die('Test cannot continue without a reference sequence build');
is($ref_seq_build->name, 'NCBI-human-build36', 'Got expected reference for test case');
my $ref_seq_input = $ref_seq_build->full_consensus_path('fa');

my $tumor_bam = "/gsc/var/cache/testsuite/data/Genome-Model-Tools-DetectVariants2-Dispatcher/flank_tumor_sorted.bam";
my $normal_bam = "/gsc/var/cache/testsuite/data/Genome-Model-Tools-DetectVariants2-Dispatcher/flank_normal_sorted.bam";

# Test dispatcher for running a complex case -- the intersect is nonsensical, but tests intersections while still keeping the test short
my $test_working_dir = File::Temp::tempdir('DetectVariants2-Dispatcher-combineXXXXX', DIR => '/gsc/var/cache/testsuite/running_testsuites/', CLEANUP => 1);
my $combine_test = $dispatcher_class->create(
    snv_detection_strategy => 'samtools r963 filtered by snp-filter v1 union samtools r963 filtered by snp-filter v1',
    output_directory => $test_working_dir,
    reference_build_id => $refbuild_id,
    aligned_reads_input => $tumor_bam,
    control_aligned_reads_input => $normal_bam,
);
ok($combine_test, "Object to test a combine case created");
ok($combine_test->execute, "Test executed successfully");

#sleep 10000000000;
done_testing();

