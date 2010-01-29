#!/usr/bin/env perl
use strict;
use warnings;

use above "Genome";
#use Test::More tests => 7;
use Test::More skip_all => "under development -rlong";

# replace with the example file and name from Mike McLellan
my $example_file_basename = 'some_file';
my $sample_name = 'SOME_SAMPLE';

my $source_dir = '/gsc/var/cache/testsuite/data/Genome-InstrumentData-Command-Import-Microarray/'; 
my $example_path = "$source_dir/$example_file_basename"; 

my $sample = Genome::Sample->get(name => $sample_name);
ok($sample, "found sample $sample_name")
;#    or die "exiting because the sample does not exist";

my $cmd = Genome::InstrumentData::Command::Import::Microarray->create(
    sample_name => $sample_name,                 # hard-coded, real sample which goes with this data
    original_data_path => $example_path,         # the param is probably different
    sequencing_platform => 'illumina microarray' 
);
ok($cmd, "constructed an import command");

my @errors = $cmd->__errors__;
is(scalar(@errors),0, "no errors");

my $result = $cmd->execute();
ok($result, "execution was successful");

my $i = Genome::InstrumentData::Imported->get(
    # put params here to get the object you made
    sample_name => $sample_name, 
    sequencing_platform => 'illumina microarray',           # not sure what this property is
);
 
my $disk = Genome::Disk::Allocation->get(owner_class_name => $i->class, owner_id => $i->id);
is($disk, $i, "found an allocation owned by the new instrument data");

my $expected_file = $i->data_directory. '/some_file';
ok(-e $expected_file, "output file is present");

is(
    Genome::Utility::FileSystem->md5sum($example_path), 
    Genome::Utility::FileSystem->md5sum($expected_file),
    "input file matches the input file" 
);


