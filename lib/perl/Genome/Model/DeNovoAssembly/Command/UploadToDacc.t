#!/usr/bin/env perl

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
};

use strict;
use warnings;

use above 'Genome';

require File::Compare;
use Test::More;

use_ok('Genome::Model::DeNovoAssembly::Command::UploadToDacc') or die;

my $base_dir = '/gsc/var/cache/testsuite/data/Genome-Model/DeNovoAssembly';
my $archive_path = $base_dir.'/inst_data/-7777/archive.tgz';
ok(-s $archive_path, 'inst data archive path') or die;
my $example_dir = $base_dir.'/soap_v9';
ok(-d $example_dir, 'example dir') or die;
my $tmpdir = File::Temp::tempdir(CLEANUP => 1);

my $taxon = Genome::Taxon->create(
    name => 'Escherichia coli TEST',
    domain => 'Bacteria',
    current_default_org_prefix => undef,
    estimated_genome_size => 4500000,
    current_genome_refseq_id => undef,
        ncbi_taxon_id => undef,
        ncbi_taxon_species_name => undef,
    species_latin_name => 'Escherichia coli',
    strain_name => 'TEST',
);
ok($taxon, 'taxon') or die;
my $sample = Genome::Sample->create(
    id => -1234,
    name => 'TEST-000',
    taxon_id => $taxon->id,
);
ok($sample, 'sample') or die;
my $library = Genome::Library->create(
    id => -12345,
    name => $sample->name.'-testlibs',
    sample_id => $sample->id,
);
ok($library, 'library') or die;

my $instrument_data = Genome::InstrumentData::Imported->create(
    id => -7777,
    sequencing_platform => 'solexa',
    read_length => 100,
    subset_name => '8-CGATGT',
    library => $library,
    median_insert_size => 260,# 181, but 260 was used to generate assembly
    read_count => 30000,
    sra_sample_id => 'SRS000000',
    is_paired_end => 1,
);
ok($instrument_data, 'instrument data');

my $pp = Genome::ProcessingProfile::DeNovoAssembly->get(2510961);#apipe soap test
ok($pp, 'pp') or die;

my $model = Genome::Model::DeNovoAssembly->create(
    processing_profile => $pp,
    subject_name => $taxon->name,
    subject_type => 'species_name',
    center_name => 'WUGC',
);
ok($model, 'de novo model') or die;
ok($model->add_instrument_data($instrument_data), 'add inst data to model');

my $build = Genome::Model::Build->create(
    model => $model,
    data_directory => $example_dir,
);
ok($build, 'create example build');
is($build->assembly_length(1000000), 1000000, 'build assembly length');
#$build->the_master_event->status('Succeeded');
#$build->the_master_event->date_completed(UR::Time->now);

no warnings;
*Genome::Model::last_succeeded_build = sub{ return $build; };
*Genome::Sys::shellcmd = sub{ return 1; };
use warnings;
ok(Genome::Sys->shellcmd(), 'shellcmd overloaded');

my $uploader = Genome::Model::DeNovoAssembly::Command::UploadToDacc->create(
    model => $model,
);
ok($uploader, 'create');
$uploader->dump_status_messages(1);
ok($uploader->execute, 'execute');

done_testing();
exit;

