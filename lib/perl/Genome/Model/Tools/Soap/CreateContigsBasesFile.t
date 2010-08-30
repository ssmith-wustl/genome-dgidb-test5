#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";
use Test::More;
require File::Compare;

use_ok ('Genome::Model::Tools::Soap::CreateContigsBasesFile') or die;

my $data_dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Soap/CreateContigsBasesFile';

ok(-d $data_dir, "Data dir exists");

my $test_file = $data_dir.'/TEST.scafSeq';
ok(-s $test_file, "Test scaffold file exists");

my $temp_dir = Genome::Utility::FileSystem->create_temp_directory();
ok(-d $temp_dir, "Temp test dir created");
mkdir $temp_dir.'/edit_dir';
ok(-d $temp_dir, "Temp test edit_dir created");

my $create = Genome::Model::Tools::Soap::CreateContigsBasesFile->create(
    scaffold_fasta_file => $test_file,
    assembly_directory => $temp_dir,
    );
ok($create, "Created gmt soap create-contigs-fasta-file");
ok( ($create->execute) == 1, "Create executed successfully");

#check
my $file_name = 'contigs.bases';
ok(-s $data_dir."/$file_name", "Data dir contigs.fasta file exists");
ok(-s $temp_dir."/edit_dir/$file_name", "Created contigs fasta file");

#compare output file
ok(File::Compare::compare("$data_dir/$file_name", "$temp_dir/edit_dir/$file_name") == 0, "Output files match");

#<STDIN>;

done_testing();

exit;
