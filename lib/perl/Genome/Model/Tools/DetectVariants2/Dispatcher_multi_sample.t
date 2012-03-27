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
use Test::More;
use above 'Genome';
use Genome::SoftwareResult;

if (Genome::Config->arch_os ne 'x86_64') {
    plan skip_all => 'requires 64-bit machine';
} else {
    plan tests => 8;
}

# THIS TESTS THE CACHING. Caching refseq in /var/cache/tgi-san. We gotta link these files to a tmp dir for tests so they don't get copied
my $refbuild_id = 101947881;
my $ref_seq_build = Genome::Model::Build::ImportedReferenceSequence->get($refbuild_id);
ok($ref_seq_build, 'human36 reference sequence build') or die;
my $refseq_tmp_dir = File::Temp::tempdir(CLEANUP => 1);

my $test_dir = "/gsc/var/cache/testsuite/data/Genome-Model-Tools-DetectVariants2-Dispatcher-multi-sample";
my $pedigree_file = "$test_dir/DS10239.ped";
#no warnings;
*Genome::Model::Build::ReferenceSequence::local_cache_basedir = sub { return $refseq_tmp_dir; };
*Genome::Model::Build::ReferenceSequence::copy_file = sub {
    my ($build, $file, $dest) = @_;
    symlink($file, $dest);
    is(-s $file, -s $dest, 'linked '.$dest) or die;
    return 1;
};
#use warnings;

#Parsing tests
my $det_class_base = 'Genome::Model::Tools::DetectVariants2';
my $dispatcher_class = "${det_class_base}::Dispatcher";
use_ok($dispatcher_class);

# TODO use alignment results that are defined in the test rather than relying on existing data
# Would need to satisfy these calls: $ar->reference_build->full_consensus_path("fa"); $ar->instrument_data; $ar->merged_alignment_bam_path; # $id->sample_name

my @test_alignment_result_ids = qw(121781692 121781691 121781695);
my @test_alignment_results = Genome::InstrumentData::AlignmentResult::Merged->get(\@test_alignment_result_ids);
is(scalar(@test_alignment_results), 3, "Got 3 test alignment results");

# Test dispatcher for running a complex case -- the intersect is nonsensical, but tests intersections while still keeping the test short
my $test_working_dir = File::Temp::tempdir('DetectVariants2-Dispatcher-multisampleXXXXX', DIR => '/gsc/var/cache/testsuite/running_testsuites/', CLEANUP => 1);
my $combine_test = $dispatcher_class->create(
    snv_detection_strategy => 'polymutt 0.02 filtered by polymutt-denovo v1',
    output_directory => $test_working_dir,
    reference_build_id => $refbuild_id,
    alignment_results => \@test_alignment_results,
    aligned_reads_sample => 'TEST',
    pedigree_file_path => $pedigree_file,
);
$combine_test->dump_status_messages(1);
#like($combine_test->reference_sequence_input, qr|^$refseq_tmp_dir|, "reference sequence path is in /tmp");
ok($combine_test, "Object to test a combine case created");
ok($combine_test->execute, "Test executed successfully");

done_testing();
