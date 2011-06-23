#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';

use Data::Dumper 'Dumper';
use Genome::Model::MetagenomicComposition16s::Test;
require File::Compare;
use Test::More;

$ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
$ENV{UR_DBI_NO_COMMIT} = 1;

use_ok('Genome::Model::Build::MetagenomicComposition16s::Solexa') or die;

# taxon, sample, lib
my $taxon = Genome::Taxon->create(
    name => 'Human Metagenome TEST',
    domain => 'Unknown',
    current_default_org_prefix => undef,
    estimated_genome_size => undef,
    current_genome_refseq_id => undef,
    ncbi_taxon_id => undef,
    ncbi_taxon_species_name => undef,
    species_latin_name => 'Human Metagenome',
    strain_name => 'TEST',
);
ok($taxon, 'create taxon');

my $sample = Genome::Sample->create(
    id => -1234,
    name => 'H_GV-933124G-S.MOCK',
    taxon_id => $taxon->id,
);
ok($sample, 'create sample');

my $library = Genome::Library->create(
    id => -12345,
    name => $sample->name.'-testlibs',
    sample_id => $sample->id,
);
ok($library, 'create library');

# inst data
my $inst_data_dir = '/gsc/var/cache/testsuite/data/Genome-Model/MetagenomicComposition16sSolexa/inst_data';
ok(-d $inst_data_dir, 'inst data dir') or die;

my $instrument_data = Genome::InstrumentData::Solexa->create(
    id => -7777,
    library => $library,
    flow_cell_id => '12345',
    lane => '1',
    median_insert_size => '22',
    run_name => '110101_TEST',
    subset_name => 4,
    run_type => 'Paired',
#   gerald_directory => '/gsc/var/cache/testsuite/data/Genome-InstrumentData-Align-Maq/test_sample_name', #needed?
    bam_path => '/gsc/var/cache/testsuite/data/Genome-InstrumentData-AlignmentResult-Bwa/input.bam',
);
ok($instrument_data, 'create inst data');

# temp test dir
my $tmpdir = Genome::Sys->create_temp_directory;

# pp
my $pp = Genome::ProcessingProfile->get(2591278); # exists and cannot recreate w/ same params
ok($pp, 'got solexa pp') or die;

# model
my $model = Genome::Model::MetagenomicComposition16s->create(
    processing_profile => $pp,
    subject_name => $sample->name,
    subject_type => 'sample_name',
    data_directory => $tmpdir,
);
ok($model, 'MC16s solexa model') or die;
ok($model->add_instrument_data($instrument_data), 'add inst data to model');

my $example_build = Genome::Model::Build->create( 
    model=> $model,
    id => -2288,
    data_directory => '/gsc/var/cache/testsuite/data/Genome-Model/MetagenomicComposition16sSolexa/build',
);
ok($example_build, 'example build') or die;

my $build = Genome::Model::Build::MetagenomicComposition16s->create(
    id => -1199,
    model => $model,
    data_directory => $model->data_directory.'/build',
);
isa_ok($build, 'Genome::Model::Build::MetagenomicComposition16s::Solexa');

ok($build->create_subdirectories, 'created subdirectories');

# calculated kb
is($build->calculate_estimated_kb_usage, 500_000, 'estimated kb usage'); 

# dirs
my $classification_dir = $build->classification_dir;
is($classification_dir, $build->data_directory.'/classification', 'classification_dir');
ok(-d $classification_dir, 'classification_dir exists');

my $fasta_dir = $build->fasta_dir;
is($fasta_dir, $build->data_directory.'/fasta', 'fasta_dir');
ok(-d $fasta_dir, 'fasta_dir exists');

# files
my $file_base = $build->file_base_name;
is($file_base, $build->subject_name, 'file base');

#< PREPARE >#
ok($build->prepare_instrument_data, 'prepare instrument data');
my @amplicon_sets = $build->amplicon_sets;
is(@amplicon_sets, 1, 'amplicon sets');
my $amplicon_set = $amplicon_sets[0];
my ($example_amplicon_set) = $example_build->amplicon_sets;
ok($example_amplicon_set, 'example amplicon set');

ok(-s $amplicon_set->processed_fasta_file, 'processed fasta file');
is(
    File::Compare::compare($amplicon_set->processed_fasta_file, $example_amplicon_set->processed_fasta_file), 
    0,
    'processed fasta file matches',
);

# metrics
is($build->amplicons_attempted, 600, 'amplicons attempted is 600');
is($build->amplicons_processed, 600, 'amplicons processed is 600');
is($build->amplicons_processed_success, '1.00', 'amplicons processed success is 1.00');
is($build->reads_attempted, 600, 'reads attempted is 600');
is($build->reads_processed, 600, 'reads processed is 600');
is($build->reads_processed_success, '1.00', 'reads processed success is 1.00');

#< CLASSIFY >#
ok($build->classify_amplicons, 'classify amplicons');
is($build->amplicons_classified, 432, 'amplicons classified');
is($build->amplicons_classification_error, 168, 'amplicons classified error');
is($build->amplicons_classified_success, '0.72', 'amplicons classified success');
my $diff_ok = Genome::Model::Build::MetagenomicComposition16s->diff_rdp(
    $example_build->classification_file_for_set_name(''),
    $build->classification_file_for_set_name(''),
);
ok($diff_ok, 'diff rdp files');

#< ORIENT >#
ok($build->orient_amplicons, 'orient amplicons');
ok(-s $amplicon_set->oriented_fasta_file, 'oriented fasta file');
is(
    File::Compare::compare($amplicon_set->oriented_fasta_file, $example_amplicon_set->oriented_fasta_file), 
    0,
    'oriented fasta file matches',
);

#print $build->data_directory;<STDIN>;
done_testing();
exit;

