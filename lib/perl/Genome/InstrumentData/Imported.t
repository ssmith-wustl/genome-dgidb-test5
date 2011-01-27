#!/usr/bin/env perl

use strict;
use warnings;

use above "Genome";

use Data::Dumper 'Dumper';
use Test::More tests => 38;

$ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = "1";
$ENV{UR_DBI_NO_COMMIT} = "1";

my $l = Genome::Library->get(sample_id=>2850539269,name=>'TEST-patient1-sample1-lib1');
ok($l, 'got library');

my $i = Genome::InstrumentData::Imported->create(
    id => -123,
    library_id              => $l->id, 
    import_source_name      => 'Broad',
    original_data_path      => '/tmp/foo',
    import_format           => 'bam',
    sequencing_platform     => 'solexa',
    description             => 'big ugly bwa file',
    read_count              => 1000,
    base_count              => 100000,
);

ok($i, "created a new imported instrument data");
isa_ok($i,"Genome::InstrumentData::Imported");
is($i->id,-123, "id is set");
is($i->sequencing_platform,'solexa','platform is correct');
is($i->user_name, $ENV{USER}, "user name is correct");
ok($i->import_date, "date is set");
is($i->library, $l, 'library');
is($i->library_name, $l->name, 'library name');
ok($i->sample, 'sample');
ok($i->sample_name, 'sample name');
ok($i->source, 'source');
ok($i->source_name, 'source name');
ok($i->taxon, 'taxon');
ok($i->species_name, 'species name');

#print Data::Dumper::Dumper($i);

my $i2 = Genome::InstrumentData::Imported->create(
    id => -456,
    library_id              => $l->id, 
    import_source_name      => 'Broad',
    original_data_path      => '/tmp/nst',
    import_format           => 'bam',
    sequencing_platform     => '454',
    description             => 'big ugly bwa file',
    read_count              => 1000,
    base_count              => 100000,
);

ok($i2, "created a new imported instrument data");
isa_ok($i2,"Genome::InstrumentData::Imported");
is($i2->id, -456, "id is set");
is($i2->sequencing_platform,'454','platform is correct');
is($i2->user_name, $ENV{USER}, "user name is correct");
ok($i2->import_date, "date is set");


# Test Imported.pm against fastq data

my $i3 = Genome::InstrumentData::Imported->create(
    id => -789,
    library_id              => $l->id, 
    import_source_name      => 'Broad',
    original_data_path      => '/gsc/var/cache/testsuite/data/Genome-InstrumentData-Command-Import-Fastq/s_5_1_sequence.txt,/gsc/var/cache/testsuite/data/Genome-InstrumentData-Command-Import-Fastq/s_5_2_sequence.txt',
    import_format           => 'fastq',
    sequencing_platform     => 'solexa',
    description             => 'fastq import test',
    read_count              => 1000,
    base_count              => 100000,
    run_name                => '12345-65432-FC666',
);

ok($i3, "created a new imported instrument data");
isa_ok($i3,"Genome::InstrumentData::Imported");
is($i3->id,-789, "id is set");
is($i3->sequencing_platform,'solexa','platform is correct');
is($i3->user_name, $ENV{USER}, "user name is correct");
is($i3->import_format, "fastq","import format = fastq");
is($i3->original_data_path, "/gsc/var/cache/testsuite/data/Genome-InstrumentData-Command-Import-Fastq/s_5_1_sequence.txt,/gsc/var/cache/testsuite/data/Genome-InstrumentData-Command-Import-Fastq/s_5_2_sequence.txt", "original_data_path matches");
is($i3->calculate_alignment_estimated_kb_usage, "585", "estimated kb usage is correct");
is($i3->run_name, "12345-65432-FC666", "run_name is correct");
is($i3->short_run_name, "FC666", "short_run_name is correct");

note('genotype microarray');
my $i4 = Genome::InstrumentData::Imported->create(
    library_id              => $l->id, 
    import_source_name      => 'TCGA',
    original_data_path      => '/gsc/var/cache/testsuite/data/Genome-InstrumentData-Command-Import-Fastq/s_5_1_sequence.txt,/gsc/var/cache/testsuite/data/Genome-InstrumentData-Command-Import-Fastq/s_5_2_sequence.txt',
    import_format           => 'illumina genotype array',
    sequencing_platform     => 'iscan',
    description             => 'Imported iscan genotype micrarray file from TCGA',
);
ok($i4, "created a new imported instrument data");
isa_ok($i4,"Genome::InstrumentData::Imported");
my $alloc = Genome::Disk::Allocation->__define__(
    #id => $id,
    #allocator_id => $id,
    allocation_path => 'imported-test',
    disk_group_name => 'info-alignments',
    owner_class_name => $i4->class,
    owner_id => $i4->id,
    kilobytes_requested => 0,
    kilobytes_used => 0,
    mount_path => '/test',
    group_subdirectory => 'inst_data',
);
ok($alloc, 'created disk alloc');
is_deeply($i4->disk_allocations, $alloc, 'got disk alloc');
my $build36_file = $i4->genotype_microarray_file_for_human_version_36;
is($build36_file, $alloc->absolute_path.'/'.$l->sample_name.'.human-36.genotype', 'human 36 genotype microarray file');
my $build37_file = $i4->genotype_microarray_file_for_human_version_37;
is($build37_file, $alloc->absolute_path.'/'.$l->sample_name.'.human-37.genotype', 'human 37 genotype microarray file');

my $ok;
eval { $ok = UR::Context->_sync_databases(); };
ok($ok, "saves to the database!");

#UR::Context->commit;
#call $instrument_data->delete to delete

done_testing();
exit;

