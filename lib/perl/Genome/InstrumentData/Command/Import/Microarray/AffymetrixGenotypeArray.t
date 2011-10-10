#!/usr/bin/env perl

use strict;
use warnings;

use above "Genome";

use Data::Dumper;
use Test::More;

if (Genome::Config->arch_os ne 'x86_64') {
    plan skip_all => 'requires 64-bit machine';
}

$ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
$ENV{UR_DBI_NO_COMMIT} = 1;

UR::DataSource->next_dummy_autogenerated_id;
do {
    $UR::DataSource::last_dummy_autogenerated_id = int($UR::DataSource::last_dummy_autogenerated_id / 10);
} until length($UR::DataSource::last_dummy_autogenerated_id) < 9;
diag('Dummy ID: '.$UR::DataSource::last_dummy_autogenerated_id);
cmp_ok(length($UR::DataSource::last_dummy_autogenerated_id), '<',  9, 'dummy id is shorter than 9 chars');

my $source_dir = '/gsc/var/cache/testsuite/data/Genome-InstrumentData-Command-Import-Microarray/affy'; 
my $reference = Genome::Model::Build::ImportedReferenceSequence->get(name => "NCBI-human-build36");
ok (-s $source_dir, "our example imported file exists");

my $sample_name = 'TEST-patient1-sample1';
my $sample = Genome::Sample->get(name => $sample_name);
is($sample->name ,$sample_name, "found sample $sample_name") or die;

my $cmd = Genome::InstrumentData::Command::Import::Microarray::AffymetrixGenotypeArray->create(
    sample => $sample,
    original_data_path => $source_dir,
    reference_sequence_build => $reference,
    description => 'TEST imprted affymetrix',
);
ok($cmd, "constructed an import command");
$cmd->dump_status_messages(1);
my @errors = $cmd->__errors__;
is(@errors, 0, "no errors in cmd");
ok($cmd->execute(), "execute");

my $instrument_data = $cmd->_instrument_data;
ok($instrument_data, 'instrument data');
is($instrument_data->sequencing_platform, 'affymetrix', 'sequencing platform');
is($instrument_data->library_name, $sample_name.'-microarraylib', 'library name');
is($instrument_data->original_data_path, $source_dir, "found imported data and source_data_path is properly set");
ok($instrument_data->allocations, "disk allocation");
ok($instrument_data->data_directory, "data directory");
my $data_directory = $instrument_data->data_directory;
ok(-d $data_directory, "data directory is present");
my @files = glob($data_directory.'/*');
is(@files, 5, 'instrument data file number is correct');
my $genotype_file = $instrument_data->genotype_microarray_file_for_reference_sequence_build($reference);
ok(-s $genotype_file, 'created genotype file');

my $ssize = Genome::Sys->directory_size_recursive($source_dir);
my $dsize = Genome::Sys->directory_size_recursive($instrument_data->data_directory);
cmp_ok($ssize, '<=', $dsize, "source and destination sizes match");

my $model = $cmd->_model;
ok($model, 'created model');
my $build = $model->last_succeeded_build;
ok($build, 'got build');
my $snp_array_file = $build->formatted_genotype_file_path;
ok(-s $snp_array_file, 'created snp array file');
my $snvs_bed = $build->snvs_bed;
ok(-s $snvs_bed, 'created snvs bed file');

done_testing();
exit;

