#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;

BEGIN {
    if (`uname -a` =~ /x86_64/) {
        plan tests => 8;
    } else {
        plan skip_all => 'Must run on a 64 bit machine';
    }

    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
    $ENV{UR_DBI_NO_COMMIT} = 1;
};

use above 'Genome';

use_ok('Genome::InstrumentData::AlignmentResult::Tophat');

# Override lock name because if people cancel tests locks don't get cleaned up.
*Genome::SoftwareResult::_resolve_lock_name = sub {
    return Genome::Sys->create_temp_file_path;
};

*Genome::InstrumentData::AlignmentResult::Tophat::estimated_kb_usage = sub {
    return 1_000_000; #This test data is far smaller than real data
};

#
# Gather up versions for the tools used herein
#
###############################################################################
my $aligner_name = "tophat";
my $aligner_tools_class_name = "Genome::Model::Tools::" . Genome::InstrumentData::AlignmentResult->_resolve_subclass_name_for_aligner_name($aligner_name);
my $alignment_result_class_name = "Genome::InstrumentData::AlignmentResult::" . Genome::InstrumentData::AlignmentResult->_resolve_subclass_name_for_aligner_name($aligner_name);

my $samtools_version = Genome::Model::Tools::Sam->default_samtools_version;
#my $picard_version = Genome::Model::Tools::Picard->default_picard_version; 
# Currently cannot use the default version because we need at least 1.29 to use gmt picard reset-sam
my $picard_version = '1.29';
my $aligner_version = '1.3.0';
my $bowtie_version = '0.12.7';

my $FAKE_INSTRUMENT_DATA_ID=-123456;

#
# Gather up the reference sequences and instrument data.
#
###########################################################

my $reference_model = Genome::Model::ImportedReferenceSequence->get(name => 'TEST-human');
ok($reference_model, "got reference model");

my $reference_build = $reference_model->build_by_version('1');
ok($reference_build, "got reference build");


my @instrument_data = generate_fake_instrument_data();

#
# Begin
#

my @params = (
     aligner_name=>$aligner_name,
     aligner_version=>$aligner_version,
     samtools_version=>$samtools_version,
     picard_version=>$picard_version,
     reference_build => $reference_build,
     bowtie_version => $bowtie_version,
     instrument_data_id => [map($_->id, @instrument_data)],
     test_name => 'tophat_unit_test',
);

my $alignment_result = Genome::InstrumentData::AlignmentResult::Tophat->create(@params);

isa_ok($alignment_result, 'Genome::InstrumentData::AlignmentResult::Tophat', 'produced merged alignment result');

my $expected_dir = '/gsc/var/cache/testsuite/data/Genome-InstrumentData-AlignmentResult-Tophat/expected_v1.3.0_1-lane';

for my $file (qw(alignment_stats.txt junctions.bed)) {
    my $path = join('/', $alignment_result->output_dir, $file);
    my $expected_path = join('/', $expected_dir, $file);
    my $diff = Genome::Sys->diff_file_vs_file($path, $expected_path);

    ok(!$diff, $file . ' matches expected result')
        or diag("diff:\n". $diff);
}

my $existing_alignment_result = Genome::InstrumentData::AlignmentResult::Tophat->get_or_create(@params);
is($existing_alignment_result, $alignment_result, 'got back the previously created result');

# Setup methods

sub generate_fake_instrument_data {

    my $fastq_directory = '/gsc/var/cache/testsuite/data/Genome-InstrumentData-Align-Maq/test_sample_name';

    my @instrument_data;
    #for my $i (0,2) {
    my $i = 0;
        my $instrument_data = Genome::InstrumentData::Solexa->create(
            id => $FAKE_INSTRUMENT_DATA_ID + $i,
            sequencing_platform => 'solexa',
            flow_cell_id => '12345',
            lane => 4 + $i,
            #seq_id => $FAKE_INSTRUMENT_DATA_ID + $i,
            median_insert_size => '22',
            sd_above_insert_size => '100',
            clusters => '600',
            read_length => '50',
            #sample_name => 'test_sample_name',
            #library_name => 'test_sample_name-lib1',
            run_name => 'test_run_name',
            subset_name => 4 + $i,
            run_type => 'Paired End Read 2',
            gerald_directory => $fastq_directory,
            bam_path => '/gsc/var/cache/testsuite/data/Genome-InstrumentData-AlignmentResult-Bwa/input.bam',
            #sample_type => 'dna',
            #sample_id => '2791246676',
            library_id => '2792100280',
        );

        isa_ok($instrument_data, 'Genome::InstrumentData::Solexa');
        push @instrument_data, $instrument_data;
    #}

    return @instrument_data;
}
