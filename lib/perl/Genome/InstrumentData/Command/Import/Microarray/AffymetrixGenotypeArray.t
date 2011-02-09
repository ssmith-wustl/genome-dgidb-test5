#!/usr/bin/env perl
use strict;
use warnings;
$ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = "1";
$ENV{UR_DBI_NO_COMMIT} = "1";
use above "Genome";
use Test::More tests => 14;
use File::Temp;
use Data::Dumper;
use File::Find;

my $sample_name = 'TEST-patient1-sample1';

my $dummy_id = UR::DataSource->next_dummy_autogenerated_id -1;
my $source_dir = '/gsc/var/cache/testsuite/data/Genome-InstrumentData-Command-Import-Microarray/affy'; 
my $source_file = '/gsc/var/cache/testsuite/data/Genome-InstrumentData-Command-Import-Microarray/affy/2351-250knsp.brlmm.txt.really.small';
my $reference = Genome::Model::Build::ImportedReferenceSequence->get(name => "NCBI-human-build36");

ok (-s $source_dir, "our example imported file exists");

my $sample = Genome::Sample->get(name => $sample_name);

is($sample->name,$sample_name, "found sample $sample_name")
    or die "exiting because the sample does not exist";

my $tmp_dir = File::Temp::tempdir('Genome-InstrumentData-Command-Import-Microarray-XXXXX', DIR => '/tmp', CLEANUP => 1);
my $tmp_allocation = Genome::Disk::Allocation->__define__(
                                                           id => '-123459',
                                                           disk_group_name => 'info_alignments',
                                                           group_subdirectory => 'test',
                                                           mount_path => '/tmp/mount_path',
                                                           allocation_path => 'microarray_data/imported/-830001',
                                                           id => '-123459',
                                                           kilobytes_requested => 100000,
                                                           kilobytes_used => 0,
                                                           owner_id => $dummy_id,#-830002,#$dummy_idi,
                                                           owner_class_name => 'Genome::InstrumentData::Imported',
                                                       );

no warnings;
*Genome::Disk::Allocation::absolute_path = sub { return $tmp_dir };
*Genome::Disk::Allocation::reallocate = sub { 1 };
*Genome::Disk::Allocation::deallocate = sub { 1 };
# Overload define - a model for this already exists, and and this will fail.
#  Set defined model instead and test at end
#my $defined_model;
#*Genome::Model::Command::Define::GenotypeMicroarray::execute = sub{ 
#    $defined_model = Genome::Model->get(name => "H_KU-6888-D59687.illumina/wugc");
#    return 1;
#};
use warnings;

isa_ok($tmp_allocation,'Genome::Disk::Allocation'); 

is($tmp_allocation->owner_id, $dummy_id, "owner-id is $dummy_id");
my $cmd = Genome::InstrumentData::Command::Import::Microarray::AffymetrixGenotypeArray->create(
    sample_name => $sample_name,
    original_data_path => $source_dir,
    #original_data_files => $source_file,
    sequencing_platform => 'affymetrix genotype array',
    allocation =>  $tmp_allocation,
    reference_sequence_build => $reference,
);

ok($cmd, "constructed an import command");

my @errors = $cmd->__errors__;

is(scalar(@errors),0, "no errors in cmd");

my $result = $cmd->execute();

ok($result, "execution was successful");

my $i = Genome::InstrumentData::Imported->get(  
    sample_name => $sample_name, 
    sequencing_platform => 'affymetrix genotype array',      
);

is($i->original_data_path,$source_dir,"found imported data and source_data_path is properly set");
ok($i->library_name =~ m/-microarraylib$/, "library is a '-microarraylib' ... library is " . $i->library_name);

my $disk = Genome::Disk::Allocation->get(id => -123459, owner_id => $dummy_id);#owner_class_name => $owner_class_name, owner_id => $dummy_id);


ok($disk, "found an allocation owned by the new instrument data");

my $owner_class = $disk->owner_class_name;

is($owner_class, "Genome::InstrumentData::Imported", "allocation belongs to a Genome::InstrumentData::Imported");

is($disk->owner_id, $i->id, "allocation owner ID matches imported instrument data id");

ok(-e $i->data_directory, "output directory is present");

my $ssize = Genome::Sys->directory_size_recursive($source_dir);
my $dsize = Genome::Sys->directory_size_recursive($i->data_directory);


ok($ssize<=$dsize, "source and destination sizes match")
    or die "Source directory size($ssize bytes) did not match or excede destination directory size($dsize), dircopy did not succeed.";
